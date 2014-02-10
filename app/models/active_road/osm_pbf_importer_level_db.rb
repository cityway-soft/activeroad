require 'leveldb-native'

module ActiveRoad
  class OsmPbfImporterLevelDb
    include OsmPbfImporter

    @@kc_batch_size = 100000
    cattr_reader :kc_batch_size

    attr_reader :ways_database_path, :nodes_database_path, :pbf_file

    def initialize(pbf_file, nodes_database_path = "/tmp/osm_pbf_nodes_leveldb", ways_database_path = "/tmp/osm_pbf_ways_leveldb")
      @pbf_file = pbf_file
      @nodes_database_path = nodes_database_path
      @ways_database_path = ways_database_path
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
      
    def authorized_tags
      @authorized_tags ||= ["highway", "railway"]
    end
    
    def iterate_nodes
      p "Begin to backup nodes in PostgreSql"

      start = Time.now
      nodes_counter = 0
      junctions_values = []    
      junctions_ways = {}
      nodes_database_size = nodes_database.count
      
      # traverse records by iterator      
      nodes_database.each { |key, value|
        nodes_counter += 1
        node = Marshal.load(value)
        geometry = GeoRuby::SimpleFeatures::Point.from_x_y( node.lon, node.lat, 4326) if( node.lon && node.lat )
        
        if node.ways.present? && (node.ways.count >= 2 || node.end_of_way == true )  # Take node with at least two ways or at the end of a way
          junctions_values << [ node.id, geometry ]
          junctions_ways[ node.id ] = node.ways
        end        
        
        junction_values_size = junctions_values.size
        if junction_values_size > 0 && (junction_values_size == @@pg_batch_size || nodes_counter == nodes_database_size)
          backup_nodes_pgsql(junctions_values, junctions_ways)
          
          #Reset
          junctions_values = []    
          junctions_ways = {}
        end
      }    
      
      p "Finish to backup #{nodes_counter} nodes in PostgreSql in #{(Time.now - start)} seconds"         
    end
    
    def import
      delete_nodes_database
      delete_ways_database
      
      backup_nodes
      backup_ways
      iterate_nodes
      iterate_ways
      backup_relations_pgsql
      
      close_nodes_database
      close_ways_database
    end

    def backup_nodes
      p "Begin to backup nodes in LevelDB nodes_database in #{nodes_database_path}"
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

            select_tags = selected_tags(node[:tags], nodes_selected_tags_keys)         
            nodes_database[ node[:id].to_s ] = Marshal.dump(Node.new(node[:id].to_s, node[:lon], node[:lat], [], select_tags [:addr_housenumber]))      
          end
        end
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains ways
        break unless nodes_parser.next
      end
      p "Finish to backup #{nodes_counter} nodes in LevelDB nodes_database in #{(Time.now - start)} seconds"
    end  

    def backup_ways
      puts "Begin to backup ways and update way in nodes in LevelDB"
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
            select_tags = selected_tags(way[:tags], way_selected_tags_keys)
            opt_tags = selected_tags(way[:tags], way_optionnal_tags_keys)
            node_ids = way.key?(:refs) ? way[:refs].collect(&:to_s) : []            
            geometry = way_geometry(node_ids)

            # Don't add way if no geometry
            if geometry.present?
              # Don't add way to nodes if a way is a boundary
              if select_tags["boundary"].blank?               
                update_node_with_way(way_id, node_ids)
              end
              ways_database[ way_id ] = Marshal.dump( Way.new( way_id, geometry, node_ids, car?(opt_tags), bike?(opt_tags), train?(opt_tags), pedestrian?(opt_tags), select_tags["name"], select_tags["maxspeed"], select_tags["oneway"], select_tags["boundary"], select_tags["admin_level"], opt_tags ) )        
            end
          end            
        end        
        
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains ways
        break unless ways_parser.next        
      end

      p "Finish to backup #{ways_counter} ways and update way in nodes in LevelDB  in #{(Time.now - start)} seconds"
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

    def iterate_ways
      puts "Begin to backup ways in PostgreSql"
      start = Time.now
   
      ways_counter = 0 
      physical_road_values = []
      attributes_by_objectid = {}
      ways_database_size = ways_database.count

      # traverse records by iterator      
      ways_database.each { |key, value|
        ways_counter += 1        
        way = Marshal.load(value)

        unless way.boundary.present?
          spherical_factory = ::RGeo::Geographic.spherical_factory
          length_in_meter = spherical_factory.line_string(way.geometry.points.collect(&:to_rgeo)).length
          physical_road_values << [way.id, way.geometry, length_in_meter, way.options]
          attributes_by_objectid[way.id] = physical_road_conditionnal_costs(way)
        end

        if (physical_road_values.count == @@pg_batch_size || (ways_database_size == ways_counter && physical_road_values.present?) )
          backup_ways_pgsql(physical_road_values, attributes_by_objectid)
          
          # Reset  
          physical_road_values = []
          attributes_by_objectid = {}
        end
      }
      p "Finish to backup #{ways_counter} ways in PostgreSql in #{(Time.now - start)} seconds"      
    end

    def backup_relations_pgsql
      puts "Begin to backup relations in PostgreSql"
      start = Time.now
      relations_parser = ::PbfParser.new(pbf_file)
      relations_counter = 0
      boundaries_columns = [:objectid, :geometry, :name, :admin_level, :postal_code, :insee_code]
      boundaries_values = []
      
      # Process the file until it finds any relation.
      relations_parser.next until relations_parser.relations.any?
      
      # Once it found at least one relation, iterate to find the remaining relations.     
      until relations_parser.relations.empty?
        relations_parser.relations.each do |relation|
          relations_counter+= 1
          
          if relation.key?(:tags) && required_relation?(relation[:tags])
            tags = selected_tags(relation[:tags], relation_selected_tags_keys)

            # relation_members = {}.tap do |relation_members|
            #   relation_members[:outer_ways] = []
            #   relation_members[:inner_ways] = []
            #   relation[:members][:ways].each do |way|
            #     relation_members[:outer_ways] << way[:id] if way[:role] == "outer"
            #     relation_members[:inner_ways] << way[:id] if way[:role] == "inner"
            #   end
            # end

            if tags["admin_level"] == "8"
              broken_geometry = false
              
              ways_geometry = [].tap do |ways_geometry|
                relation[:members][:ways].each do |member_way|
                  way = ways_database[ member_way[:id].to_s ]
                  if way.present?
                    way_values = Marshal.load(way)
                  else
                    p "Geometry error : impossible to find way #{member_way[:id]} for relation #{relation[:id]}"
                    broken_geometry = true
                    break
                  end
                  ways_geometry <<  way_values.geometry if  way_values.geometry.present?
                end
              end

              if !broken_geometry
                boundary_geometry = GeoRuby::SimpleFeatures::MultiPolygon.from_polygons([GeoRuby::SimpleFeatures::Polygon.from_linear_rings(ways_geometry)])
              
                boundaries_values << [ relation[:id], boundary_geometry, tags["name"], tags["admin_level"], tags["addr:postcode"], tags["ref:INSEE"] ]
                boundaries_values_size = boundaries_values.size
              
                if boundaries_values_size > 0 && (boundaries_values_size == @@pg_batch_size || relations_counter == boundaries_values_size)
                  ActiveRoad::Boundary.import(boundaries_columns, boundaries_values, :validate => false)
                
                # Reset  
                  boundaries_values = []
                end
              end
            end
          end            
        end        
        
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains relations
        break unless relations_parser.next        
      end

      p "Finish to backup #{relations_counter} relations in PostgreSql  in #{(Time.now - start)} seconds"
    end
    
  end
end
