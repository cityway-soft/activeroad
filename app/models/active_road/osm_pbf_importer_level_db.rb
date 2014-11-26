require 'leveldb-native'
require 'csv'

module ActiveRoad
  class OsmPbfImporterLevelDb
    include OsmPbfImporter

    @@csv_batch_size = 100000
    cattr_reader :csv_batch_size

    attr_reader :ways_database_path, :nodes_database_path, :physical_roads_database_path, :junctions_database_path, :pbf_file, :split_ways

    def initialize(pbf_file, split_ways = false, prefix_path = "/tmp/")
      @pbf_file = pbf_file
      @split_ways = split_ways
      FileUtils.mkdir_p(prefix_path) if !Dir.exists?(prefix_path)
      @nodes_database_path = prefix_path + "osm_pbf_nodes_leveldb"
      @ways_database_path = prefix_path + "osm_pbf_ways_leveldb"
      @junctions_database_path = prefix_path + "osm_pbf_junctions_leveldb"
      @physical_roads_database_path = prefix_path + "osm_pbf_physical_roads_leveldb"
    end

    def geos_factory
      ActiveRoad::Base.geos_factory
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

    def junctions_database
      @junctions_database ||= LevelDBNative::DB.make junctions_database_path, :create_if_missing => true, :block_cache_size => 16 * 1024 * 1024
    end

    def close_junctions_database
      junctions_database.close!
    end

    def delete_junctions_database
      FileUtils.remove_entry junctions_database_path if File.exists?(junctions_database_path)
    end

    def physical_roads_database
      @physical_roads_database ||= LevelDBNative::DB.make physical_roads_database_path, :create_if_missing => true, :block_cache_size => 16 * 1024 * 1024
    end
    
    def close_physical_roads_database
      physical_roads_database.close!
    end

    def delete_physical_roads_database
      FileUtils.remove_entry physical_roads_database_path if File.exists?(physical_roads_database_path)
    end

    def display_time(time_difference)
      Time.at(time_difference.to_i).utc.strftime "%H:%M:%S"
    end
    
    def import
      delete_nodes_database
      delete_ways_database
      delete_junctions_database
      delete_physical_roads_database

      leveldb_import
      postgres_import
      
      close_nodes_database
      close_ways_database
      close_junctions_database
      close_physical_roads_database
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

      save_junctions_and_physical_roads_temporary
      save_physical_road_conditionnal_costs_and_junctions

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
      Rails.logger.info "Finish to backup #{nodes_counter} nodes in LevelDB nodes_database in #{display_time(Time.now - start)} seconds"
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
        nodes_readed = {}
        nodes_database.batch do |batch|
          ways_parser.ways.each do |way|            
            way_id = way[:id].to_s
            
            if way.key?(:tags) && required_way?(@@way_for_physical_road_required_tags_keys, way[:tags])
              # Don't add way to nodes if a way is a boundary
              select_tags = selected_tags(way[:tags], @@way_selected_tags_keys)
              node_ids = way.key?(:refs) ? way[:refs].collect(&:to_s) : []
              
              if node_ids.present? && node_ids.size > 1
                ways_counter+= 1
                node_ids.each do |node_id|
                  if nodes_readed.has_key?(node_id)                    
                    node = nodes_readed[node_id]
                  else
                    node = Marshal.load(nodes_database[node_id])
                  end
                  node.add_way(way_id)
                  node.end_of_way = true if [node_ids.first, node_ids.last].include?(node_id)
                  nodes_readed[node_id] = node
                end
              end        
            end
          end
          nodes_readed.each_pair do |node_readed_id, node_readed|
            batch[node_readed_id] = Marshal.dump(node_readed)
          end
        end        
        
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains ways
        break unless ways_parser.next        
      end

      Rails.logger.info "Finish to update #{ways_counter} ways in nodes in LevelDB  in #{display_time(Time.now - start)} seconds"
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
            way_id = way[:id].to_s
            
            if way.key?(:tags) && required_way?(@@way_required_tags_keys, way[:tags])
              select_tags = selected_tags(way[:tags], @@way_selected_tags_keys)
              opt_tags = selected_tags(way[:tags], @@way_optionnal_tags_keys)
              node_ids = way.key?(:refs) ? way[:refs].collect(&:to_s) : []
    
              way = Way.new( way_id, node_ids, car?(opt_tags), bike?(opt_tags), train?(opt_tags), pedestrian?(opt_tags), select_tags["name"], select_tags["maxspeed"], select_tags["oneway"], select_tags["boundary"], select_tags["admin_level"], select_tags["addr:housenumber"], opt_tags )

              ways_splitted = (way.boundary.present? || way.addr_housenumber.present?) ? [way] : split_way_with_nodes(way) # Don't split boundary and adress way               
              
              ways_splitted.each do |way_splitted|
                ways_counter+= 1
                batch[ way_splitted.id ] = Marshal.dump( way_splitted )        
              end
            end
          end
        end        
        
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains ways
        break unless ways_parser.next        
      end

      Rails.logger.info "Finish to backup #{ways_counter} ways in LevelDB  in #{display_time(Time.now - start)} seconds"
    end

    def split_way_with_nodes(way)
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

      ways_splitted = []
      ways_nodes.each_with_index do |way_nodes, index|                
        way_tags = way.options.dup         
        way_tags["first_node_id"] = way_nodes.first.id
        way_tags["last_node_id"] =  way_nodes.last.id

        # Don't add way if node_ids contains less than 2 nodes
        if way_nodes.present? && way_nodes.size > 1
          ways_splitted <<  Way.new( way.id + "-#{index}", way_nodes.collect(&:id), way.car, way.bike, way.train, way.pedestrian, way.name, way.maxspeed, way.oneway, way.boundary, way.admin_level, way.addr_housenumber, way_tags )
        end        
      end

      ways_splitted
    end
    
    def iterate_nodes
      Rails.logger.debug "Begin to backup nodes in PostgreSql"

      start = Time.now
      nodes_counter = street_numbers_counter = 0
      junctions_values = []
      street_numbers_values = []    
      nodes_database_size = nodes_database.count
      
      # traverse records by iterator
      junction_columns = ["objectid", "geometry", "created_at", "updated_at"]
      street_number_columns = ["objectid", "geometry", "number", "street", "city", "state", "country", "location_on_road", "physical_road_id", "tags", "created_at", "updated_at"]
      
      CSV.open("/tmp/junctions.csv", "wb:UTF-8") do |junctions_csv|        
        CSV.open("/tmp/street_numbers.csv", "wb:UTF-8") do |street_numbers_csv|          
          junctions_csv << junction_columns
          street_numbers_csv << street_number_columns
          
          nodes_database.each { |key, value|            
            node = Marshal.load(value)
            geometry = geos_factory.point( node.lon, node.lat, 4326) if( node.lon && node.lat )
            
            if node.ways.present? && (node.ways.count >= 2 || node.end_of_way == true )  # Take node with at least two ways or at the end of a way
              nodes_counter += 1
              junctions_csv << [ node.id, geometry.as_text, Time.now, Time.now ]
            end       
            
            if node.addr_housenumber.present?
              street_numbers_counter += 1
              physical_road_id = ActiveRoad::StreetNumber.computed_linked_road(geometry, node.tags["addr_street"])
              location_on_road = physical_road_id.present? ? ActiveRoad::StreetNumber.computed_location_on_road(geometry) : nil
              
              street_numbers_csv << [ node.id, geometry.as_text, node.addr_housenumber, node.tags["addr_street"], node.tags["addr_city"], node.tags["addr_state"], node.tags["addr_country"], physical_road_id, location_on_road, "#{node.tags.to_s.gsub(/[{}]/, '')}", Time.now, Time.now ]
            end
              
          }
        end
      end
             
      ActiveRoad::Junction.transaction do                                         
        ActiveRoad::Junction.copy_from "/tmp/junctions.csv"
      end
      
      ActiveRoad::StreetNumber.transaction do
        ActiveRoad::StreetNumber.copy_from "/tmp/street_numbers.csv"
      end
      
      Rails.logger.info "Finish to backup #{nodes_counter} nodes and #{street_numbers_counter} street numbers in PostgreSql in #{display_time(Time.now - start)} seconds"         
    end

    def iterate_ways
      Rails.logger.info "Begin to backup ways in PostgreSql"
      start = Time.now
   
      ways_counter = 0
      street_numbers_counter = 0
      ways_database_size = ways_database.count

      # traverse records by iterator
      physical_road_columns = ["objectid", "car", "bike", "train", "pedestrian", "name", "geometry", "boundary_id", "tags", "created_at", "updated_at"]
      street_number_columns = ["objectid", "geometry", "number", "street", "city", "state", "country", "location_on_road", "physical_road_id", "tags", "created_at", "updated_at"]
      
      CSV.open("/tmp/physical_roads.csv", "wb:UTF-8") do |physical_roads_csv|
        CSV.open("/tmp/street_numbers2.csv", "wb:UTF-8") do |street_numbers_csv|          
          physical_roads_csv << physical_road_columns
          street_numbers_csv << street_number_columns
          
          ways_database.each { |key, value|          
            way = Marshal.load(value)
            
            unless way.boundary.present? # Use ways not used in relation for boundaries
              nodes = []
              way.nodes.each_with_index do |node_id, index|
                node = Marshal.load( nodes_database[node_id.to_s] )
                nodes << node                
              end
              way_geometry = way_geometry(nodes)
              
              if way.addr_housenumber.present? # If ways with adress
                street_numbers_counter += 1
                geometry = way_geometry.envelope.centroid

                physical_road_id = ActiveRoad::StreetNumber.computed_linked_road(geometry, way.options["addr_street"])
                location_on_road = physical_road_id.present? ? ActiveRoad::StreetNumber.computed_location_on_road(geometry) : nil
                
                street_numbers_csv << [ way.id, geometry.as_text, way.addr_housenumber, way.options["addr_street"], way.options["addr_city"], way.options["addr_state"], way.options["addr_country"], physical_road_id, location_on_road, "#{way.options.to_s.gsub(/[{}]/, '')}", Time.now, Time.now ]
              else
                ways_counter += 1                      
                way_boundary = way.boundary.present? ? way.boundary.to_i : nil
                physical_roads_csv << [ way.id, way.car, way.bike, way.train, way.pedestrian, way.name, way_geometry.as_text, way_boundary, "#{way.options.to_s.gsub(/[{}]/, '')}", Time.now, Time.now ]
              end
            end
          }
        end
      end
      
      # Save physical roads
      ActiveRoad::PhysicalRoad.transaction do                                         
        ActiveRoad::PhysicalRoad.copy_from "/tmp/physical_roads.csv"
      end

      ActiveRoad::StreetNumber.transaction do                                         
        ActiveRoad::StreetNumber.copy_from "/tmp/street_numbers2.csv"        
      end

      Rails.logger.info "Finish to backup #{ways_counter} ways and #{street_numbers_counter} street numbers in PostgreSql in #{display_time(Time.now - start)} seconds"
    end

    def save_junctions_and_physical_roads_temporary
      Rails.logger.info "Begin to backup physical_roads and junctions in LevelDb"
      
      start = Time.now      
      junctions_database.batch do |batch|
        ActiveRoad::Junction.select("id,objectid").find_each do |junction|
          junctions_database[junction.objectid] = junction.id.to_s
        end
      end

      physical_roads_database.batch do |batch|
        ActiveRoad::PhysicalRoad.select("id,objectid").find_each do |physical_road|
          physical_roads_database[physical_road.objectid] = physical_road.id.to_s 
        end
      end

      Rails.logger.info "Finish to backup physical_roads and junctions in LevelDb in #{display_time(Time.now - start)} seconds"
    end

    def save_physical_road_conditionnal_costs_and_junctions
      Rails.logger.info "Begin to backup ways in PostgreSql"
      
      start = Time.now
      physical_road_conditionnal_costs_counter = junctions_physical_roads_counter = 0
      physical_road_conditionnal_cost_columns = ["tags", "cost", "physical_road_id"]
      junction_physical_road_columns = ["physical_road_id", "junction_id"]
      
      CSV.open("/tmp/physical_road_conditionnal_costs.csv", "wb:UTF-8") do |physical_road_conditionnal_costs_csv|
        CSV.open("/tmp/junctions_physical_roads.csv", "wb:UTF-8") do |junctions_physical_roads_csv|
          physical_road_conditionnal_costs_csv << physical_road_conditionnal_cost_columns
          junctions_physical_roads_csv << junction_physical_road_columns
          
          ways_database.each { |key, value|
            way = Marshal.load(value)

            # Save physical road conditionnal cost not for boundaries or street numbers
            unless way.boundary.present? || way.addr_housenumber.present?
              way_conditionnal_costs = physical_road_conditionnal_costs(way)
              way_conditionnal_costs.each do |way_conditionnal_cost|
                physical_road_conditionnal_costs_counter += 1
                physical_road_conditionnal_costs_csv << way_conditionnal_cost + [ physical_roads_database[way.id] ]
              end

              way.nodes.uniq.each do |node_id|
                junction_id = junctions_database[node_id]
                junctions_physical_roads_counter += 1
                junctions_physical_roads_csv << [ physical_roads_database[way.id], junction_id ] if junction_id.present?
              end
            end
          }
        end
      end
      
      # Save physical road conditionnal costs
      ActiveRoad::PhysicalRoadConditionnalCost.transaction do                                         
        ActiveRoad::PhysicalRoadConditionnalCost.copy_from "/tmp/physical_road_conditionnal_costs.csv"
      end

      # Save physical road and junctions link
      ActiveRoad::JunctionsPhysicalRoad.transaction do                                         
        ActiveRoad::JunctionsPhysicalRoad.copy_from "/tmp/junctions_physical_roads.csv"
      end

      Rails.logger.info "Finish to backup #{junctions_physical_roads_counter} junctions_physical_roads and #{physical_road_conditionnal_costs_counter} physical_road_conditionnal_costs in PostgreSql in #{display_time(Time.now - start)} seconds"
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
          intersection_geometry = geos_factory.parse_wkt("#{result['intersection_geometry']}")

          # Not take in consideration point intersection!!
          if RGeo::Feature::LineString === intersection_geometry
            simple_way = SimpleWay.new(result["boundary_id"], result["physical_road_id"], result["physical_road_objectid"], result["physical_road_tags"], geos_factory.parse_wkt("#{result['physical_road_geometry']}"), result["departure_objectid"], geos_factory.parse_wkt("#{result['departure_geometry']}"), result["arrival_objectid"], geos_factory.parse_wkt("#{result['arrival_geometry']}"), intersection_geometry )
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
          difference_geometry = geos_factory.parse_wkt("#{result['difference_geometry']}")
          if RGeo::Feature::LineString === difference_geometry
            simple_way = SimpleWay.new(nil, result["physical_road_id"], result["physical_road_objectid"], result["physical_road_tags"], geos_factory.parse_wkt("#{result['physical_road_geometry']}"), result["departure_objectid"], geos_factory.parse_wkt("#{result['departure_geometry']}"), result["arrival_objectid"], geos_factory.parse_wkt("#{result['arrival_geometry']}"), difference_geometry )
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
      
      Rails.logger.info "Finish to split and affect boundaries to ways in PostgreSql in #{display_time(Time.now - start)} seconds"
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
        points << geos_factory.point(node.lon, node.lat)
      end

      geos_factory.line_string(points) if points.present? &&  1 < points.count     
    end   

    def find_boundary(way_geometry)
      ActiveRoad::Boundary.first_contains(way_geometry)
    end    

    def backup_relations_pgsql
      Rails.logger.info "Begin to backup relations in PostgreSql"
      start = Time.now
      relations_parser = ::PbfParser.new(pbf_file)
      boundaries_counter = 0
      
      # traverse records by iterator
      boundary_columns = ["objectid", "geometry", "name", "admin_level", "postal_code", "insee_code"]     
      
      # Process the file until it finds any relation.
      relations_parser.next until relations_parser.relations.any?
      
      # Once it found at least one relation, iterate to find the remaining relations.
      CSV.open("/tmp/boundaries.csv", "wb:UTF-8") do |boundary_csv|       
        boundary_csv << boundary_columns

        until relations_parser.relations.empty?
          relations_parser.relations.each do |relation|
            
            if relation.key?(:tags) && required_relation?(relation[:tags])
              tags = selected_tags(relation[:tags], @@relation_selected_tags_keys)
              
              # Use tags["admin_level"] == "8" because catholic boundaries exist!!
              if tags["admin_level"] == "8" && tags["boundary"] == "administrative"
                boundaries_counter += 1
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
                    boundary_geometry = geos_factory.multi_polygon( boundary_polygons ).as_text
                    
                    boundary_csv << [ relation[:id], boundary_geometry, tags["name"], tags["admin_level"], tags["addr:postcode"], tags["ref:INSEE"] ]
                  end
                rescue StandardError => e
                  Rails.logger.error "Geometry error : impossible to build polygon for relation #{tags["name"]} with id #{relation[:id]} : #{e.message}"
                end
              end
            end
          end
          
          # When there's no more fileblocks to parse, #next returns false
          # This avoids an infinit loop when the last fileblock still contains relations
          break unless relations_parser.next                 
        end
      end
      
      ActiveRoad::Boundary.transaction do                                         
        ActiveRoad::Boundary.copy_from "/tmp/boundaries.csv"
      end
      
      Rails.logger.info  "Finish to backup #{boundaries_counter} boundaries in PostgreSql  in #{display_time(Time.now - start)} seconds"
    end

    def backup_logical_roads_pgsql
      Rails.logger.info "Begin to backup logical roads in PostgreSql"
      start = Time.now
      logical_roads_counter = 0

      saved_name = nil
      saved_boundary = nil
      saved_logical_road = nil
      ActiveRoad::PhysicalRoad.where("physical_roads.name IS NOT NULL OR physical_roads.boundary_id IS NOT NULL").select("name,boundary_id,id").order(:boundary_id,:name).find_in_batches(batch_size: 2000) do |group|
        ActiveRoad::LogicalRoad.transaction do
          group.each do |physical_road|
            not_same_name = (saved_name != physical_road.name)
            not_same_boundary = (saved_boundary != physical_road.boundary_id)
            
            saved_name = physical_road.name if not_same_name
            saved_boundary = physical_road.boundary_id if not_same_boundary

            if not_same_name || not_same_boundary
              logical_roads_counter += 1
              saved_logical_road = ActiveRoad::LogicalRoad.create(:name => saved_name, :boundary_id => saved_boundary)
            end
            
            physical_road.update_column(:logical_road_id, saved_logical_road.id) if saved_logical_road.present?
          end
        end
      end
            
      Rails.logger.info "Finish to backup #{logical_roads_counter} logical roads in PostgreSql in #{ display_time(Time.now - start)} seconds"
    end
    

  end
end
