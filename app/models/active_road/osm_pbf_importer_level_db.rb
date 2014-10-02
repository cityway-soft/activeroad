require 'leveldb-native'
require 'csv'

module ActiveRoad
  class OsmPbfImporterLevelDb
    include OsmPbfImporter

    @@leveldb_batch_size = 100000
    cattr_reader :leveldb_batch_size

    attr_reader :ways_database_path, :nodes_database_path, :pbf_file, :split_ways

    def initialize(pbf_file, split_ways = false, nodes_database_path = "/tmp/osm_pbf_nodes_leveldb", ways_database_path = "/tmp/osm_pbf_ways_leveldb")
      @pbf_file = pbf_file
      @split_ways = split_ways
      @nodes_database_path = nodes_database_path
      @ways_database_path = ways_database_path
    end

    def nodes_database
      @nodes_database ||= LevelDBNative::DB.make nodes_database_path, :create_if_missing => true, :block_cache_size => 16 * 1024 * 1024
    end

    def close_nodes_database
      nodes_database.close!
    end

    def delete_nodes_database
      FileUtils.remove_entry nodes_database_path if File.exists?(nodes_database_path)
    end

    def ways_database
      @ways_database ||= LevelDBNative::DB.make ways_database_path, :create_if_missing => true, :block_cache_size => 16 * 1024 * 1024
    end
    
    def close_ways_database
      ways_database.close!
    end

    def delete_ways_database
      FileUtils.remove_entry ways_database_path if File.exists?(ways_database_path)
    end     
    
    def iterate_nodes
      Rails.logger.debug "Begin to backup nodes in PostgreSql"

      start = Time.now
      nodes_counter = 0
      junctions_values = []
      street_numbers_values = []    
      nodes_database_size = nodes_database.count
      
      # traverse records by iterator      
      nodes_database.each { |key, value|
        nodes_counter += 1
        node = Marshal.load(value)
        geometry = GeoRuby::SimpleFeatures::Point.from_x_y( node.lon, node.lat, 4326) if( node.lon && node.lat )

        if node.ways.present? && (node.ways.count >= 2 || node.end_of_way == true )  # Take node with at least two ways or at the end of a way
          junctions_values << [ node.id, geometry.as_hex_ewkb, Time.now, Time.now ]
        end       

        if node.addr_housenumber.present?
          street_numbers_values << [ node.id, geometry.as_hex_ewkb, node.addr_housenumber, "#{node.tags.to_s.gsub(/[{}]/, '')}", Time.now, Time.now ]
        end
      }
        
      junction_columns = ["objectid", "geometry", "created_at", "updated_at"]
      CSV.open("/tmp/junctions.csv", "wb:UTF-8") do |csv|
        csv << junction_columns
        junctions_values.each do |junction_values|
          csv << junction_values
        end        
      end
      ActiveRoad::Junction.transaction do                                         
        ActiveRoad::Junction.pg_copy_from "/tmp/junctions.csv"
      end
      
      street_number_columns = ["objectid", "geometry", "number", "tags", "created_at", "updated_at"]
      CSV.open("/tmp/street_numbers.csv", "wb:UTF-8") do |csv|
        csv << street_number_columns
        street_numbers_values.each do |street_number_values|
          csv << street_number_values
        end        
      end
      ActiveRoad::StreetNumber.transaction do
        ActiveRoad::StreetNumber.pg_copy_from "/tmp/street_numbers.csv"
      end
      
      Rails.logger.info "Finish to backup #{nodes_counter} nodes in PostgreSql in #{(Time.now - start)} seconds"         
    end
    
    def import
      delete_nodes_database
      delete_ways_database

      leveldb_import
      postgres_import
      
      close_nodes_database
      close_ways_database
    end

    def leveldb_import
      # Save nodes in temporary file
      backup_nodes
      # Update nodes with ways in temporary file
      update_nodes_with_way
      # Save ways in temporary file
      backup_ways      
    end
      
    def postgres_import
      # Save nodes in junctions
      iterate_nodes      
      
      # Save relations in boundary
      backup_relations_pgsql if split_ways

      # Save ways in physical roads
      iterate_ways

      # Split and affect boundary to each way     
      split_way_with_boundaries if split_ways
      
      # Save logical roads from physical roads
      backup_logical_roads_pgsql if split_ways
    end
    
    def backup_nodes
      Rails.logger.info "Begin to backup nodes in LevelDB nodes_database in #{nodes_database_path}"
      start = Time.now
      nodes_parser = ::PbfParser.new(pbf_file)
      nodes_counter = 0
      nodes_hash = {}

      # Process the file until it finds any node
      nodes_parser.next until nodes_parser.nodes.any?
      
      until nodes_parser.nodes.empty?
        nodes_database.batch do |batch|
          last_node = nodes_parser.nodes.last
          nodes_parser.nodes.each do |node|
            nodes_counter+= 1

            select_tags = selected_tags(node[:tags], @@nodes_selected_tags_keys)         
            batch[ node[:id].to_s ] = Marshal.dump(Node.new(node[:id].to_s, node[:lon], node[:lat], select_tags["addr:housenumber"], [], false, select_tags))      
          end
        end
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains ways
        break unless nodes_parser.next
      end
      Rails.logger.info "Finish to backup #{nodes_counter} nodes in LevelDB nodes_database in #{(Time.now - start)} seconds"
    end
    
    def update_nodes_with_way
      Rails.logger.info "Update way in nodes in LevelDB"
      start = Time.now
      ways_parser = ::PbfParser.new(pbf_file)
      ways_counter = 0 
      
      # Process the file until it finds any way.
      ways_parser.next until ways_parser.ways.any?
      
      # Once it found at least one way, iterate to find the remaining ways.     
      until ways_parser.ways.empty?
        #nodes_database.batch do |batch|
          ways_parser.ways.each do |way|
            ways_counter+= 1
            way_id = way[:id].to_s
            
            if way.key?(:tags) && required_way?(way[:tags])
              # Don't add way to nodes if a way is a boundary
              select_tags = selected_tags(way[:tags], @@way_selected_tags_keys)
              node_ids = way.key?(:refs) ? way[:refs].collect(&:to_s) : []
              
              if select_tags["boundary"].blank? && node_ids.present? && node_ids.size > 1
                node_ids.each do |node_id|
                  node = Marshal.load(nodes_database[node_id])
                  node.add_way(way_id)
                  node.end_of_way = true if [node_ids.first, node_ids.last].include?(node_id)
                  nodes_database[node_id] = Marshal.dump(node)
                end
              end        
            end
          #end
        end        
        
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains ways
        break unless ways_parser.next        
      end

      Rails.logger.info "Finish to update #{ways_counter} ways in nodes in LevelDB  in #{(Time.now - start)} seconds"
    end

    # def update_node_with_way(way_id, node_ids)
    #   # Update node data with way id
    #   node_ids.each do |node_id|
    #     node = Marshal.load(nodes_database[node_id])
    #     node.add_way(way_id)
    #     node.end_of_way = true if [node_ids.first, node_ids.last].include?(node_id)
    #     nodes_database[node_id] = Marshal.dump(node)
    #   end
    # end
    
    def backup_ways
      Rails.logger.info "Begin to backup ways in LevelDB"
      start = Time.now
      ways_parser = ::PbfParser.new(pbf_file)
      ways_counter = 0 
      
      # Process the file until it finds any way.
      ways_parser.next until ways_parser.ways.any?
      
      # Once it found at least one way, iterate to find the remaining ways.     
      until ways_parser.ways.empty?
        ways_database.batch do |batch|
          ways_parser.ways.each do |way|
            ways_counter+= 1
            way_id = way[:id].to_s
            
            if way.key?(:tags) && required_way?(way[:tags])            
              select_tags = selected_tags(way[:tags], @@way_selected_tags_keys)
              opt_tags = selected_tags(way[:tags], @@way_optionnal_tags_keys)
              node_ids = way.key?(:refs) ? way[:refs].collect(&:to_s) : []

              # Add  node_id_first and node_id_last to opt_tags
              opt_tags.merge!( { "first_node_id" => node_ids.first.to_s, "last_node_id" => node_ids.last.to_s } ) if node_ids.present?            

              # Don't add way if node_ids contains less than 2 nodes
              if node_ids.present? && node_ids.size > 1
                batch[ way_id ] = Marshal.dump( Way.new( way_id, node_ids, car?(opt_tags), bike?(opt_tags), train?(opt_tags), pedestrian?(opt_tags), select_tags["name"], select_tags["maxspeed"], select_tags["oneway"], select_tags["boundary"], select_tags["admin_level"], opt_tags ) )        
              end
            end
          end
        end        
        
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains ways
        break unless ways_parser.next        
      end

      Rails.logger.info "Finish to backup #{ways_counter} ways in LevelDB  in #{(Time.now - start)} seconds"
    end

    def iterate_ways
      Rails.logger.info "Begin to backup ways in PostgreSql"
      start = Time.now
   
      ways_counter = 0 
      physical_roads_values = {}
      ways_database_size = ways_database.count

      # traverse records by iterator      
      ways_database.each { |key, value|
        ways_counter += 1        
        way = Marshal.load(value)
        
        unless way.boundary.present?
          physical_roads_values.merge!( split_way_with_nodes(way) )
        end
      }
      
      # Save physical roads
      physical_road_columns = ["objectid", "car", "bike", "train", "pedestrian", "name", "geometry", "boundary_id", "tags", "created_at", "updated_at"]
      CSV.open("/tmp/physical_roads.csv", "wb:UTF-8") do |csv|
        csv << physical_road_columns       
        physical_roads_values.values.each do |physical_road_values|
          csv << [ physical_road_values[:objectid], physical_road_values[:car], physical_road_values[:bike], physical_road_values[:train], physical_road_values[:pedestrian], physical_road_values[:name], physical_road_values[:geometry], physical_road_values[:boundary_id], "#{physical_road_values[:tags].to_s.gsub(/[{}]/, '')}", Time.now, Time.now ]
        end        
      end
      ActiveRoad::PhysicalRoad.transaction do                                         
        ActiveRoad::PhysicalRoad.pg_copy_from "/tmp/physical_roads.csv"
      end

      physical_road_from_way = Hash[ ActiveRoad::PhysicalRoad.select([:id, :objectid]).map{ |p| [p.objectid, p.id] } ]
      
      # Save physical road conditionnal costs
      physical_road_conditionnal_cost_columns = ["tags", "cost", "physical_road_id"]

      CSV.open("/tmp/physical_road_conditionnal_costs.csv", "wb:UTF-8") do |csv|
        csv << physical_road_conditionnal_cost_columns
        physical_roads_values.values.each do |physical_road_values|
          physical_road_values[:conditionnal_costs].each do |conditionnal_cost|
            csv << conditionnal_cost + [ physical_road_from_way[physical_road_values[:objectid]] ]
          end
        end        
      end
      ActiveRoad::PhysicalRoadConditionnalCost.transaction do                                         
        ActiveRoad::PhysicalRoadConditionnalCost.pg_copy_from "/tmp/physical_road_conditionnal_costs.csv"
      end
            
      # Save physical road and junctions link
      junction_from_node = Hash[ ActiveRoad::Junction.select([:id, :objectid]).map{ |j| [j.objectid, j.id] } ]
      
      junction_physical_road_columns = ["physical_road_id", "junction_id"]
      CSV.open("/tmp/junctions_physical_roads.csv", "wb:UTF-8") do |csv|
        csv << junction_physical_road_columns
        physical_roads_values.values.each do |physical_road_values|
          physical_road_values[:junctions].each do |junction_objectid|
            junction_id = junction_from_node[junction_objectid]            
            csv << [ physical_road_from_way[physical_road_values[:objectid]], junction_id ] if junction_id.present? # Hack normaly must have only nodes used for physical road
          end
        end        
      end
      ActiveRoad::JunctionsPhysicalRoad.transaction do                                         
        ActiveRoad::JunctionsPhysicalRoad.pg_copy_from "/tmp/junctions_physical_roads.csv"
      end
            
      Rails.logger.info "Finish to backup #{ways_counter} ways in PostgreSql in #{(Time.now - start)} seconds"      
    end

    def split_way_with_nodes(way)

      way_conditionnal_costs = physical_road_conditionnal_costs(way)
      nodes_used = []
      nodes = []
      # Get nodes really used and all nodes (used and for geometry need) for a way
      way.nodes.each_with_index do |node_id, index|
        node = Marshal.load( nodes_database[node_id.to_s] )
        nodes << node
        nodes_used << index if node.used?
      end

      ways_nodes = []
      # Split way between each nodes used
      if split_ways
        nodes_used.each_with_index do |before_node, index|        
          ways_nodes << nodes.values_at(before_node..nodes_used[ index + 1]) if before_node != nodes_used.last
        end
      else
        ways_nodes = [nodes]
      end

      physical_road_values = {}
      ways_nodes.each_with_index do |way_nodes, index|
        way_geometry = way_geometry(way_nodes)
        
        physical_road_tags = way.options.dup         
        physical_road_tags["first_node_id"] = way_nodes.first.id
        physical_road_tags["last_node_id"] =  way_nodes.last.id
        physical_road_values[way.id + "-#{index}"] = {:objectid => way.id + "-#{index}", :car => way.car, :bike => way.bike, :train => way.train, :pedestrian =>  way.pedestrian, :name =>  way.name, :geometry => way_geometry.as_hex_ewkb, :boundary_id => nil, :tags => physical_road_tags, :conditionnal_costs => way_conditionnal_costs, :junctions => way_nodes.collect(&:id)}
      end

      physical_road_values
    end

    def split_way_with_boundaries
      Rails.logger.info "Begin to split and affect boundaries to ways in PostgreSql"
      start = Time.now

      # Update physical roads entirely contains in boundaries
      ActiveRoad::PhysicalRoad.connection.select_all("SELECT physical_road.id AS physical_road_id, boundary.id AS boundary_id FROM physical_roads physical_road, boundaries boundary WHERE ST_Covers( boundary.geometry, physical_road.geometry)").each_slice(@@pg_batch_size) do |group|
        ActiveRoad::PhysicalRoad.transaction do 
          group.each do |element|
            ActiveRoad::PhysicalRoad.update(element["physical_road_id"], :boundary_id => element["boundary_id"])
          end
        end
      end

      if split_ways
        simple_ways = []
        simple_ways_not_line_string = 0

        # Fix : Produce 2 ways when way is tangent to boundary borders for each boundary
        # Get geometries in boundary      
        sql = "SELECT b.id AS boundary_id, p.id AS physical_road_id, p.objectid AS physical_road_objectid, p.tags AS physical_road_tags, ST_AsText(p.geometry) AS physical_road_geometry, 
j1.objectid AS departure_objectid, ST_AsText(j1.geometry) AS departure_geometry, 
j2.objectid AS arrival_objectid, ST_AsText(j2.geometry) AS arrival_geometry, 
ST_AsText( (ST_Dump(ST_Intersection( p.geometry , b.geometry))).geom ) AS intersection_geometry 
FROM physical_roads p, boundaries b, junctions j1, junctions j2, junctions_physical_roads jp, junctions_physical_roads jp2 
WHERE p.boundary_id IS NULL AND ST_Crosses( b.geometry, p.geometry)
AND j1.id = jp.junction_id AND p.id = jp.physical_road_id AND ST_Equals(ST_StartPoint(p.geometry), j1.geometry)
AND j2.id = jp2.junction_id AND p.id = jp2.physical_road_id AND ST_Equals(ST_EndPoint(p.geometry), j2.geometry)".gsub(/^( |\t)+/, "")      
        ActiveRoad::PhysicalRoad.connection.select_all( sql ).each do |result|
          intersection_geometry = GeoRuby::SimpleFeatures::Geometry.from_ewkt("SRID=#{ActiveRoad.srid};#{result['intersection_geometry']}")

          # Not take in consideration point intersection!!
          if intersection_geometry.class == GeoRuby::SimpleFeatures::LineString
            simple_way = SimpleWay.new(result["boundary_id"], result["physical_road_id"], result["physical_road_objectid"], result["physical_road_tags"], GeoRuby::SimpleFeatures::Geometry.from_ewkt("SRID=#{ActiveRoad.srid};#{result['physical_road_geometry']}"), result["departure_objectid"], GeoRuby::SimpleFeatures::Geometry.from_ewkt("SRID=#{ActiveRoad.srid};#{result['departure_geometry']}"), result["arrival_objectid"], GeoRuby::SimpleFeatures::Geometry.from_ewkt("SRID=#{ActiveRoad.srid};#{result['arrival_geometry']}"), intersection_geometry )
            # Delete boucle line string Ex : 9938647-4
            simple_ways << simple_way if simple_way.departure != simple_way.arrival
          else
            simple_ways_not_line_string += 1
          end
        end
        
        # Get geometries not in boundaries      
        sql = "SELECT ST_AsText( (ST_Dump(difference_geometry)).geom ) AS difference_geometry, v.id AS physical_road_id, v.objectid AS physical_road_objectid, v.tags AS physical_road_tags, ST_AsText(v.geometry) AS physical_road_geometry,
j1.objectid AS departure_objectid, ST_AsText(j1.geometry) AS departure_geometry, 
j2.objectid AS arrival_objectid, ST_AsText(j2.geometry) AS arrival_geometry
FROM 
( SELECT pr.id, pr.objectid, pr.tags, pr.geometry, pr.boundary_id, ST_Difference( pr.geometry, ST_Union( b.geometry)) as difference_geometry 
FROM physical_roads pr, boundaries b 
WHERE pr.boundary_id IS NULL AND ST_Crosses( b.geometry, pr.geometry)
GROUP BY pr.id, pr.geometry) v, 
junctions j1, junctions j2, junctions_physical_roads jp, junctions_physical_roads jp2
WHERE j1.id = jp.junction_id AND v.id = jp.physical_road_id AND ST_Equals(ST_StartPoint(v.geometry), j1.geometry)
AND j2.id = jp2.junction_id AND v.id = jp2.physical_road_id AND ST_Equals(ST_EndPoint(v.geometry), j2.geometry)
AND NOT ST_IsEmpty(difference_geometry)".gsub(/^( |\t)+/, "") 
        ActiveRoad::PhysicalRoad.connection.select_all( sql ).each do |result|
          difference_geometry = GeoRuby::SimpleFeatures::Geometry.from_ewkt("SRID=#{ActiveRoad.srid};#{result['difference_geometry']}")
          if difference_geometry.class == GeoRuby::SimpleFeatures::LineString
            simple_way = SimpleWay.new(nil, result["physical_road_id"], result["physical_road_objectid"], result["physical_road_tags"], GeoRuby::SimpleFeatures::Geometry.from_ewkt("SRID=#{ActiveRoad.srid};#{result['physical_road_geometry']}"), result["departure_objectid"], GeoRuby::SimpleFeatures::Geometry.from_ewkt("SRID=#{ActiveRoad.srid};#{result['departure_geometry']}"), result["arrival_objectid"], GeoRuby::SimpleFeatures::Geometry.from_ewkt("SRID=#{ActiveRoad.srid};#{result['arrival_geometry']}"), difference_geometry )
            # Delete boucle line string Ex : 9938647-4
            simple_ways << simple_way if simple_way.departure != simple_way.arrival
          else
            simple_ways_not_line_string += 1
          end
        end
       
        # Prepare reordering ways         
        simple_ways_by_old_physical_road_id = simple_ways.group_by{|sw| sw.old_physical_road_id}

        # Hack : in the code we take the first one which has an intersection point and it deletes
        # dual segment tangent on the boundary borders 
        simple_ways_by_old_physical_road_id.each do |old_physical_road_id, ways|
          ways.each do |way|
            if way.departure == way.old_departure_geometry
              way.departure_objectid = way.old_departure_objectid
              way.previous = nil
            else
              way.departure_objectid = way.default_departure_objectid
              way.previous = ways.detect{ |select_way| select_way.arrival == way.departure }
            end
            
            if way.arrival == way.old_arrival_geometry
              way.arrival_objectid = way.old_arrival_objectid
              way.next = nil 
            else
              way.arrival_objectid = way.default_arrival_objectid
              way.next = ways.detect{ |select_way| select_way.departure == way.arrival }
            end          
          end
        end       

        # Save new ways and junctions
        #physical_roads ||= ActiveRoad::PhysicalRoad.where(:objectid => simple_ways_by_old_physical_road_id.keys).includes(:conditionnal_costs)
        
        simple_ways_by_old_physical_road_id.each_slice(1000) { |group|
          ActiveRoad::PhysicalRoad.transaction do            
            
            group.each do |old_physical_road_id, ways|
              #puts ways.sort.inspect             
              next_way = ways.detect{ |select_way| select_way.previous == nil }
              way_counter = 0
              junction_counter = 0

              
              while next_way != nil
                start = Time.now

                #old_physical_road = physical_roads.where(:id => old_physical_road_id)               
                #physical_road.conditionnal_costs = old_physical_road.conditionnal_costs

                # Create departure
                if next_way.previous != nil
                  departure = ActiveRoad::Junction.where(:objectid => "#{next_way.departure_objectid}-#{junction_counter}").first_or_create( :geometry => next_way.departure )
                  junction_counter += 1
                else
                  departure = ActiveRoad::Junction.find_by_objectid(next_way.departure_objectid) 
                end
                
                # Create arrival
                if next_way.next != nil
                  arrival = ActiveRoad::Junction.where(:objectid => "#{next_way.arrival_objectid}-#{junction_counter}").first_or_create( :geometry => next_way.arrival )
                else
                  arrival = ActiveRoad::Junction.find_by_objectid(next_way.arrival_objectid)
                end

                old_physical_road_tags = next_way.old_physical_road_tags_hash
                old_physical_road_tags["first_node_id"] = departure.objectid
                old_physical_road_tags["last_node_id"] =  arrival.objectid 
                
                physical_road = ActiveRoad::PhysicalRoad.create! :objectid => "#{next_way.old_physical_road_objectid}-#{way_counter}", :boundary_id => next_way.boundary_id, :geometry => next_way.geometry, :tags => old_physical_road_tags
                
                # Add departure and arrival to physical road
                physical_road.junctions << [departure, arrival]

                way_counter += 1

                if way_counter > ways.size
                  Rails.logger.error "Infinite boucle when save physical road splitted with boundaries"
                  raise Exception.new "Infinite boucle when save physical road splitted with boundaries"
                end
                
                next_way = next_way.next                                
              end
              
            end
          end
        }
        
        # Delete old ways
        ActiveRoad::PhysicalRoad.destroy(simple_ways_by_old_physical_road_id.keys)
      end
      
      Rails.logger.info "Finish to split and affect boundaries to ways in PostgreSql in #{(Time.now - start)} seconds"
    end

    class SimpleWay
      include Comparable
      attr_accessor :boundary_id, :old_physical_road_id, :old_physical_road_objectid, :old_physical_road_tags, :old_physical_road_geometry, :old_departure_objectid, :old_departure_geometry, :old_arrival_objectid, :old_arrival_geometry, :departure_objectid, :arrival_objectid, :geometry, :next, :previous
        
      def initialize(boundary_id, old_physical_road_id, old_physical_road_objectid, old_physical_road_tags, old_physical_road_geometry, old_departure_objectid, old_departure_geometry, old_arrival_objectid, old_arrival_geometry, geometry)
        @boundary_id = boundary_id
        @old_physical_road_id = old_physical_road_id
        @old_physical_road_objectid = old_physical_road_objectid
        @old_physical_road_tags = old_physical_road_tags || ""
        @old_physical_road_geometry = old_physical_road_geometry
        @old_departure_objectid = old_departure_objectid
        @old_departure_geometry = old_departure_geometry
        @old_arrival_objectid = old_arrival_objectid
        @old_arrival_geometry = old_arrival_geometry
        @geometry = geometry       
      end

      def old_physical_road_tags_hash
        #Fix tags build from string
        tags = {}.tap do |tags| 
          old_physical_road_tags.split(',').each do |pair|                    
            key, value = pair.split("=>")
            tags[key.gsub(/\W/, "")] = value.gsub(/\W/, "")
          end
        end
      end
      
      def departure
        #puts "geometry class #{geometry.class}, value #{geometry.inspect}"
        geometry.points.first if geometry
      end

      def arrival
        geometry.points.last if geometry
      end      
      
      def default_departure_objectid
        "#{old_departure_objectid}-#{old_arrival_objectid}"
      end
      
      def default_arrival_objectid
        "#{old_departure_objectid}-#{old_arrival_objectid}"
      end

      def <=>(another)
        # puts "self : #{self.departure.inspect}, #{self.arrival.inspect}"
        # puts "another : #{another.departure.inspect}, #{another.arrival.inspect}"
        # puts old_physical_road_geometry.points.inspect
        # puts old_physical_road_geometry.points.index(another.arrival).inspect
        # puts old_physical_road_geometry.points.index(self.departure).inspect
        if self.departure == another.arrival || old_physical_road_geometry.points.index(another.arrival) < old_physical_road_geometry.points.index(self.departure)         
          1
        elsif self.arrival == another.departure || old_physical_road_geometry.points.index(self.arrival) < old_physical_road_geometry.points.index(another.departure)
          -1
        else
          nil
        end
      end
      
    end    
    
    def way_geometry(nodes)
      points = []
      nodes.each do |node|
        points << GeoRuby::SimpleFeatures::Point.from_x_y(node.lon, node.lat, 4326)
      end

      GeoRuby::SimpleFeatures::LineString.from_points(points, 4326) if points.present? &&  1 < points.count     
    end   

    def find_boundary(way_geometry)
      ActiveRoad::Boundary.first_contains(way_geometry)
    end    

    def backup_relations_pgsql
      Rails.logger.info "Begin to backup relations in PostgreSql"
      start = Time.now
      relations_parser = ::PbfParser.new(pbf_file)
      relations_counter = 0
      boundaries_values = []
      
      # Process the file until it finds any relation.
      relations_parser.next until relations_parser.relations.any?
      
      # Once it found at least one relation, iterate to find the remaining relations.     
      until relations_parser.relations.empty?
        relations_parser.relations.each do |relation|
          relations_counter+= 1
          
          if relation.key?(:tags) && required_relation?(relation[:tags])
            tags = selected_tags(relation[:tags], @@relation_selected_tags_keys)
            
            # Use tags["admin_level"] == "8" because catholic boundaries exist!!
            if tags["admin_level"] == "8" && tags["boundary"] == "administrative"
              outer_ways = {}
              inner_ways = {}
              
              begin 
                relation[:members][:ways].each do |member_way|                  
                  way_data = ways_database[ member_way[:id].to_s ]
                  way = nil
                  nodes = []
                  
                  if way_data.present?
                    way = Marshal.load(way_data)
                    way.nodes.each do |node_id|
                      node = Marshal.load( nodes_database[node_id.to_s] )
                      nodes << node
                    end
                  else
                    raise StandardError, "Geometry error : impossible to find way #{member_way[:id]} for relation #{tags["name"]} with id #{relation[:id]}"                      
                  end
                  
                  if  member_way[:role] == "inner"
                    inner_ways[ member_way[:id] ] = way_geometry(nodes)
                  elsif member_way[:role] == "outer"
                    outer_ways[ member_way[:id] ] = way_geometry(nodes)
                  else # Fix : lot of boundaries have no tags role
                    outer_ways[ member_way[:id] ] = way_geometry(nodes)
                  end
                end
                
                boundary_polygons = extract_relation_polygon(outer_ways.values, inner_ways.values)
                
                if boundary_polygons.present?
                  boundary_geometry = GeoRuby::SimpleFeatures::MultiPolygon.from_polygons( boundary_polygons ).as_hex_ewkb
                  
                  boundaries_values << [ relation[:id], boundary_geometry, tags["name"], tags["admin_level"], tags["addr:postcode"], tags["ref:INSEE"] ]
                end
              rescue StandardError => e
                p "Geometry error : impossible to build polygon for relation #{tags["name"]} with id #{relation[:id]} : #{e.message}"
              end                
            end
          end            
        end
        
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains relations
        break unless relations_parser.next                 
      end

      boundary_columns = ["objectid", "geometry", "name", "admin_level", "postal_code", "insee_code"]
      CSV.open("/tmp/boundaries.csv", "wb:UTF-8") do |csv|
        csv << boundary_columns
        boundaries_values.each do |boundary_values|
          csv << boundary_values
        end        
      end
      ActiveRoad::Boundary.transaction do                                         
        ActiveRoad::Boundary.pg_copy_from "/tmp/boundaries.csv"
      end
      
      Rails.logger.info  "Finish to backup #{relations_counter} relations in PostgreSql  in #{(Time.now - start)} seconds"
    end

    def backup_logical_roads_pgsql
      Rails.logger.info "Begin to backup logical roads in PostgreSql"
      start = Time.now

      # sorted_physical_roads = {}.tap do |sorted_physical_roads|  
      #   Hash[ ActiveRoad::PhysicalRoad.select([:id, :boundary_id, :name]).where("physical_roads.boundary_id IS NOT NULL").group_by(&:boundary_id)].each_pair do |boundary, physical_roads|
      #     puts boundary.inspect
      #     sorted_physical_roads[boundary] = physical_roads.group_by(&:name)
      #   end
      # end

      # logical_road_columns = ["name", "boundary_id"]
      # CSV.open("/tmp/logical_roads.csv", "wb:UTF-8") do |csv|
      #   csv << logical_road_columns
      #   logical_roads_values.each do |logical_road_values|
      #     csv << logical_road_values
      #   end        
      # end
      # ActiveRoad::LogicalRoad.transaction do                                         
      #   ActiveRoad::LogicalRoad.pg_copy_from "/tmp/logical_roads.csv"
      # end
      
      ActiveRoad::PhysicalRoad.find_in_batches(batch_size: 2000) do |group|
        ActiveRoad::LogicalRoad.transaction do
          group.each do |physical_road|
            # TODO : use geographical data to know if it's the same logical road or not
            logical_road = ActiveRoad::LogicalRoad.where(["name = :name AND boundary_id = :boundary_id", {:name => physical_road.name ? physical_road.name : "", :boundary_id => physical_road.boundary_id } ]).first_or_create!(:name => physical_road.name.present? ? physical_road.name : "", :boundary_id => physical_road.boundary_id) if physical_road.boundary_id
            logical_road.physical_roads << physical_road if logical_road
          end
        end
      end
      
      
      Rails.logger.info "Finish to backup logical roads in PostgreSql in #{(Time.now - start)} seconds"
    end
    

  end
end
