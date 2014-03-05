require 'leveldb-native'

module ActiveRoad
  class OsmPbfImporterLevelDb
    include OsmPbfImporter

    @@leveldb_batch_size = 100000
    cattr_reader :leveldb_batch_size

    attr_reader :ways_database_path, :nodes_database_path, :pbf_file, :split_ways

    def initialize(pbf_file, nodes_database_path = "/tmp/osm_pbf_nodes_leveldb", ways_database_path = "/tmp/osm_pbf_ways_leveldb", split_ways = true)
      @pbf_file = pbf_file
      @nodes_database_path = nodes_database_path
      @ways_database_path = ways_database_path
      @split_ways = split_ways
    end

    def nodes_database
      @nodes_database ||= LevelDBNative::DB.make nodes_database_path, :create_if_missing => true
    end

    def close_nodes_database
      nodes_database.close!
    end

    def delete_nodes_database
      FileUtils.remove_entry nodes_database_path if File.exists?(nodes_database_path)
    end

    def ways_database
      @ways_database ||= LevelDBNative::DB.make ways_database_path, :create_if_missing => true
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
      street_number_values = []    
      nodes_database_size = nodes_database.count
      
      # traverse records by iterator      
      nodes_database.each { |key, value|
        nodes_counter += 1
        node = Marshal.load(value)
        geometry = GeoRuby::SimpleFeatures::Point.from_x_y( node.lon, node.lat, 4326) if( node.lon && node.lat )
        
        if node.ways.present? && (node.ways.count >= 2 || node.end_of_way == true )  # Take node with at least two ways or at the end of a way
          junctions_values << [ node.id, geometry ]
        end
        
        junction_values_size = junctions_values.size
        if junction_values_size > 0 && (junction_values_size == @@pg_batch_size || nodes_counter == nodes_database_size)
          backup_nodes_pgsql(junctions_values)
          
          #Reset
          junctions_values = []    
        end

        if node.addr_housenumber.present?
          street_number_values << [ node.id, geometry, node.addr_housenumber ]
        end

        street_number_values_size = street_number_values.size
        if street_number_values_size > 0 && (street_number_values_size == @@pg_batch_size || nodes_counter == nodes_database_size)
          backup_street_numbers_pgsql(street_number_values)
          
          #Reset
          street_number_values = []    
        end
      }
      
      Rails.logger.debug "Finish to backup #{nodes_counter} nodes in PostgreSql in #{(Time.now - start)} seconds"         
    end
    
    def import
      delete_nodes_database
      delete_ways_database

      # Save nodes in temporary file
      backup_nodes
      # Update nodes with ways in temporary file
      update_nodes_with_way
      # Save nodes in junctions
      iterate_nodes

      # Save ways in temporary file
      backup_ways      
      
      # Save relations in boundary
      backup_relations_pgsql

      # Save ways in physical roads
      iterate_ways
      
      # Save logical roads from physical roads
      backup_logical_roads_pgsql
      
      close_nodes_database
      close_ways_database
    end

    def backup_nodes
      Rails.logger.debug "Begin to backup nodes in LevelDB nodes_database in #{nodes_database_path}"
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
            nodes_database[ node[:id].to_s ] = Marshal.dump(Node.new(node[:id].to_s, node[:lon], node[:lat], select_tags["addr:housenumber"]))      
          end
        end
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains ways
        break unless nodes_parser.next
      end
      Rails.logger.debug "Finish to backup #{nodes_counter} nodes in LevelDB nodes_database in #{(Time.now - start)} seconds"
    end
    
    def update_nodes_with_way
      Rails.logger.debug "Update way in nodes in LevelDB"
      start = Time.now
      ways_parser = ::PbfParser.new(pbf_file)
      ways_counter = 0 
      
      # Process the file until it finds any way.
      ways_parser.next until ways_parser.ways.any?
      
      # Once it found at least one way, iterate to find the remaining ways.     
      until ways_parser.ways.empty?
        ways_parser.ways.each do |way|
          ways_counter+= 1
          way_id = way[:id].to_s
          
          if way.key?(:tags) && required_way?(way[:tags])                        
            # Don't add way to nodes if a way is a boundary
            select_tags = selected_tags(way[:tags], @@way_selected_tags_keys)
            node_ids = way.key?(:refs) ? way[:refs].collect(&:to_s) : []
            
            if select_tags["boundary"].blank? && node_ids.present? && node_ids.size > 1
              update_node_with_way(way_id, node_ids)
            end        
          end          
        end        
        
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains ways
        break unless ways_parser.next        
      end

      Rails.logger.debug "Finish to update #{ways_counter} ways in nodes in LevelDB  in #{(Time.now - start)} seconds"
    end

    def update_node_with_way(way_id, node_ids)
      # Update node data with way id
      node_ids.each do |node_id|
        node = Marshal.load(nodes_database[node_id])
        node.add_way(way_id)
        node.end_of_way = true if [node_ids.first, node_ids.last].include?(node_id)
        nodes_database[node_id] = Marshal.dump(node)
      end
    end
    
    def backup_ways
      Rails.logger.debug "Begin to backup ways in LevelDB"
      start = Time.now
      ways_parser = ::PbfParser.new(pbf_file)
      ways_counter = 0 
      
      # Process the file until it finds any way.
      ways_parser.next until ways_parser.ways.any?
      
      # Once it found at least one way, iterate to find the remaining ways.     
      until ways_parser.ways.empty?
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
              ways_database[ way_id ] = Marshal.dump( Way.new( way_id, node_ids, car?(opt_tags), bike?(opt_tags), train?(opt_tags), pedestrian?(opt_tags), select_tags["name"], select_tags["maxspeed"], select_tags["oneway"], select_tags["boundary"], select_tags["admin_level"], opt_tags ) )        
            end
          end            
        end        
        
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains ways
        break unless ways_parser.next        
      end

      Rails.logger.debug "Finish to backup #{ways_counter} ways in LevelDB  in #{(Time.now - start)} seconds"
    end

    def iterate_ways
      Rails.logger.debug "Begin to backup ways in PostgreSql"
      start = Time.now
   
      ways_counter = 0 
      physical_road_values = {}
      ways_database_size = ways_database.count

      # traverse records by iterator      
      ways_database.each { |key, value|
        ways_counter += 1        
        way = Marshal.load(value)

        unless way.boundary.present?          
          physical_road_values = physical_road_values.merge( split_way_with_nodes(way) )
        end

        if (physical_road_values.count >= @@pg_batch_size || (ways_database_size == ways_counter && physical_road_values.present?) )
          backup_ways_pgsql(physical_road_values)
          
          # Reset  
          physical_road_values = {}
        end
      }

      # Backup the rest of the way
      backup_ways_pgsql(physical_road_values) if physical_road_values.present?
      
      Rails.logger.debug "Finish to backup #{ways_counter} ways in PostgreSql in #{(Time.now - start)} seconds"      
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
        spherical_factory = ::RGeo::Geographic.spherical_factory
        length_in_meter = spherical_factory.line_string(way_geometry.points.collect(&:to_rgeo)).length
        
        physical_road_values[way.id + "-#{index}"] = {:objectid => way.id + "-#{index}", :car => way.car, :bike => way.bike, :train => way.train, :pedestrian =>  way.pedestrian, :name =>  way.name, :length_in_meter => length_in_meter, :geometry => way_geometry, :boundary_id => nil, :tags => way.options, :conditionnal_costs => way_conditionnal_costs, :junctions => way_nodes.collect(&:id)}
      end

      physical_road_values
    end

    class SimpleWay
      attr_accessor :boundary, :geometry
        
      def initialize(boundary, geometry)
        @boundary = boundary
        @geometry = geometry
      end

      def departure_id
        first_point = geometry.points.first
        "first_point.lon-first_point.lat"
      end
      
      def arrival_id
        last_point = geometry.points.last
        "first_point.lon-first_point.lat"
      end
      
    end

    def split_way_with_boundaries
      Rails.logger.debug "Begin to split and affect boundaries to ways in PostgreSql"
      start = Time.now
      
      ActiveRoad::PhysicalRoad.each do |physical_road|
        # Get boundaries intersected with way
        boundaries_intersected = ActiveRoad::Boundary.all_intersect(physical_road.geometry)
      
        if boundaries_intersected.blank?
          diff_and_intersect = []
          
          # Get geometries not in boundaries
          differences = (way_geometry.to_rgeo.difference(boundaries_intersected.map{ |b| b.geometry.to_rgeo }.reduce(:union) )).to_georuby
          differences.each do |difference|
            diff_and_intersect << SimpleWay.new(nil, difference) 
          end
                    
          # Get intersection geometries with boundaries
          intersections = [].tap do |intersections|
            boundaries_intersected.each do |boundary_intersected|
              geometry_intersection = boundary_intersected.intersection(way_geometry) 
              diff_and_intersect << SimpleWay.new(boundary_intersected, geometry_intersection) 
            end
          end

          # Classify differences and intersections by node
          ordered_ways = {}.tap do |ordered_ways|
            diff_and_intersect.each do |simple_way|
              ordered_ways["#{simple_way.departure_id != first_node_id ? simple_way.departure_id : first_node.id}"] = { :previous_simple_way => simple_way }    
              ordered_ways["#{simple_way.arrival_id != last_node_id ? simple_way.arrival_id : arrival_id}"] = { :next_simple_way => simple_way }
            end
          end

          puts ordered_ways["#{first_node.id}"]
        end
      end
      Rails.logger.debug "Finis to split and affect boundaries to ways in PostgreSql in #{(Time.now - start)} seconds"
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
      Rails.logger.debug "Begin to backup relations in PostgreSql"
      start = Time.now
      relations_parser = ::PbfParser.new(pbf_file)
      relations_counter = 0
      boundaries_columns = [:objectid, :geometry, :name, :admin_level, :postal_code, :insee_code]
      boundaries_values = []
      
      # Process the file until it finds any relation.
      relations_parser.next until relations_parser.relations.any?

      ActiveRoad::Boundary.transaction do 
        # Once it found at least one relation, iterate to find the remaining relations.     
        until relations_parser.relations.empty?
          relations_parser.relations.each do |relation|
            relations_counter+= 1
            
            if relation.key?(:tags) && required_relation?(relation[:tags])
              tags = selected_tags(relation[:tags], @@relation_selected_tags_keys)

              if tags["admin_level"] == "8"
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
                
                  boundary_polygon = extract_relation_polygon(outer_ways.values, inner_ways.values)

                  if boundary_polygon.present?
                    boundary_geometry = GeoRuby::SimpleFeatures::MultiPolygon.from_polygons( [boundary_polygon] )
                    borders = boundary_polygon.rings
                  
                    # boundaries_values << [ relation[:id], boundary_geometry, tags["name"], tags["admin_level"], tags["addr:postcode"], tags["ref:INSEE"] ]
                    # boundaries_values_size = boundaries_values.size                  
                  
                    #ActiveRoad::Boundary.import(boundaries_columns, boundaries_values, :validate => false)                
                    ActiveRoad::Boundary.create! :objectid => relation[:id], :geometry => boundary_geometry, :name => tags["name"], :admin_level => tags["admin_level"], :postal_code => tags["addr:postcode"], :insee_code => tags["ref:INSEE"], :borders => borders
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

      end   
      Rails.logger.debug  "Finish to backup #{relations_counter} relations in PostgreSql  in #{(Time.now - start)} seconds"
    end

  end
end
