require 'leveldb-native'
require 'csv'

module ActiveRoad
  class OsmPbfImporterLevelDb
    include OsmPbfImporter

    attr_reader :ways_database_path, :nodes_database_path, :physical_roads_database_path, :junctions_database_path, :pbf_file, :ways_split, :boundaries_split, :prefix_path

    def initialize(pbf_file, ways_split = false, boundaries_split = false, prefix_path = "/tmp")
      @pbf_file = pbf_file
      @ways_split = ways_split
      @boundaries_split = boundaries_split
      @prefix_path = prefix_path
     
      FileUtils.mkdir_p(prefix_path) if !Dir.exists?(prefix_path)
      @nodes_database_path = prefix_path + "/osm_pbf_nodes_leveldb"
      @ways_database_path = prefix_path + "/osm_pbf_ways_leveldb"
      @junctions_database_path = prefix_path + "/osm_pbf_junctions_leveldb"
      @physical_roads_database_path = prefix_path + "/osm_pbf_physical_roads_leveldb"
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
      # Save junctions
      save_junctions
      
      # Save relations in boundary
      backup_relations_pgsql

      # Save ways in physical roads
      save_physical_roads

      save_junctions_and_physical_roads_temporary
      save_physical_road_conditionnal_costs_and_junctions

      # Save street numbers after physical roads build
      save_street_numbers_from_nodes
      save_street_numbers_from_ways

      # Split and affect boundary to each way     
      split_way_with_boundaries if boundaries_split
      
      # Save logical roads from physical roads
      backup_logical_roads_pgsql
    end  

    def pedestrian?(tags)
      highway_tag_values = %w{pedestrian footway path steps}
      if tags["highway"].present? && highway_tag_values.include?(tags["highway"])
        true
      else
        false
      end
    end

    # http://wiki.openstreetmap.org/wiki/FR:Cycleway
    # http://wiki.openstreetmap.org/wiki/FR:Bicycle
    def bike?(tags)
      highway_tag_values = %w{cycleway}
      bike_tags_keys = ["cycleway:left", "cycleway:right", "cycleway", "cycleway:left"]

      if (tags["highway"].present? && highway_tag_values.include?(tags["highway"])) || (bike_tags_keys & tags.keys).present?
        true
      else
        false
      end
    end

    # http://wiki.openstreetmap.org/wiki/Key:railway
    def train?(tags)
      railway_tag_values = %w{rail tram funicular light_rail subway}
      if tags["railway"].present? && railway_tag_values.include?(tags["railway"])
        true
      else
        false
      end
    end

    # http://wiki.openstreetmap.org/wiki/FR:France_roads_tagging
    def car?(tags)
      highway_tag_values = %w{motorway trunk trunk_link primary secondary tertiary motorway_link primary_link unclassified service road residential track}
      if tags["highway"].present? && highway_tag_values.include?(tags["highway"])
        true
      else
        false
      end
    end

    def required_way?(required_tags, tags)
      (required_tags & tags.keys).present? ? true : false
    end

    def required_relation?(tags)
      @@relation_required_tags_keys.each do |require_tag_key|
        if tags.keys.include?(require_tag_key)
          return true
        end
      end
      return false
    end

    # Return an hash with tag_key => tag_value for osm attributes
    def selected_tags(tags, selected_tags_keys)
      {}.tap do |selected_tags|
        tags.each do |key, value|
          if selected_tags_keys.include?(key)
            selected_tags[key] = value
          end
        end           
      end
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
            batch[ node[:id].to_s ] = Marshal.dump(Node.new(node[:id].to_s, node[:lon], node[:lat], select_tags["addr:housenumber"], [], false, "node", select_tags))      
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

            if way.key?(:tags)
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

                  # TODO : Delete this horrible hack
                  if required_way?(@@way_for_physical_road_required_tags_keys, way[:tags])
                    node.add_way(way_id)
                    node.end_of_way = true if [node_ids.first, node_ids.last].include?(node_id)
                  elsif select_tags["addr:interpolation"]
                    node.from_osm_object = "way_address"
                  end
                                    
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
    
              way = Way.new( way_id, node_ids, car?(opt_tags), bike?(opt_tags), train?(opt_tags), pedestrian?(opt_tags), select_tags["name"], select_tags["maxspeed"], select_tags["oneway"], select_tags["boundary"], select_tags["admin_level"], select_tags["addr:housenumber"], select_tags["addr:interpolation"], opt_tags )

              ways_splitted = split_way_with_nodes(way)
              
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
      return [way] if way.options["highway"].blank? && way.options["railway"].blank? # Don't split way with  a boundary (without highway and railway)  and adress way               
      
      nodes_used = []
      nodes = []
      # Get nodes really used and all nodes (used and for geometry need) for a way
      way.nodes.each_with_index do |node_id, index|
        node = Marshal.load( nodes_database[node_id.to_s] )
        nodes << node
        nodes_used << index if node.used?
      end

      ways_nodes = []
      # Split way between each nodes used only if way is highway or railway
      if ways_split
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
          ways_splitted <<  Way.new( way.id + "-#{index}", way_nodes.collect(&:id), way.car, way.bike, way.train, way.pedestrian, way.name, way.maxspeed, way.oneway, way.boundary, way.admin_level, way.addr_housenumber, way.addr_interpolation, way_tags )
        end        
      end

      ways_splitted
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
    
    class Node
      attr_accessor :id, :lon, :lat, :ways, :end_of_way, :addr_housenumber, :from_osm_object, :tags

      def initialize(id, lon, lat, addr_housenumber = "", ways = [], end_of_way = false, from_osm_object = "", tags = {} )
        @id = id
        @lon = lon
        @lat = lat
        @addr_housenumber = addr_housenumber
        @ways = ways
        @end_of_way = end_of_way
        @from_osm_object = from_osm_object
        @tags = tags
      end

      def add_way(id)
        @ways << id
      end

      def marshal_dump
        [@id, @lon, @lat, @addr_housenumber, @ways, @end_of_way, @from_osm_object, @tags]
      end

      def marshal_load array
        @id, @lon, @lat, @addr_housenumber, @ways, @end_of_way, @from_osm_object, @tags = array
      end

      def used?
        ( ways.present? && ways.size > 1 ) || end_of_way
      end
    end

    class Way
      attr_accessor :id, :nodes, :car, :bike, :train, :pedestrian, :name, :maxspeed, :oneway, :boundary, :admin_level, :addr_housenumber, :addr_interpolation, :options

      def initialize(id, nodes = [], car = false, bike = false, train = false, pedestrian = false, name = "", maxspeed = 0, oneway = false, boundary = "", admin_level = "", addr_housenumber = "", addr_interpolation = "", options = {})
        @id = id
        @nodes = nodes
        @car = car
        @bike = bike
        @train = train
        @pedestrian = pedestrian
        @name = name
        @maxspeed = maxspeed
        @oneway = oneway
        @boundary = boundary
        @admin_level = admin_level
        @addr_housenumber = addr_housenumber
        @addr_interpolation = addr_interpolation
        @options = options
      end

      def add_node(id)
        @nodes << id
      end

      def marshal_dump
        [@id, @nodes, @car, @bike, @train, @pedestrian, @name, @maxspeed, @oneway, @boundary, @admin_level, @addr_housenumber, @addr_interpolation, @options]
      end

      def marshal_load array
        @id, @nodes, @car, @bike, @train, @pedestrian, @name, @maxspeed, @oneway, @boundary, @admin_level, @addr_housenumber, @addr_interpolation, @options = array
      end
    end
   
  end
end
