require "kyotocabinet"

module ActiveRoad
  class OsmPbfImporter
    include KyotoCabinet

    attr_reader :parser, :database_path, :xml_file, :kc_batch_size, :pg_batch_size, :progress_bar 
    
    # See for more details :  
    # http://wiki.openstreetmap.org/wiki/FR:France_roads_tagging
    # http://wiki.openstreetmap.org/wiki/FR:Cycleway
    # http://wiki.openstreetmap.org/wiki/Key:railway
    @@tag_for_car_values = %w{motorway trunk trunk_link primary secondary tertiary motorway_link primary_link unclassified service road residential track}
    cattr_reader :tag_for_car_values

    @@tag_for_pedestrian_values = %w{pedestrian footway path steps}
    cattr_reader :tag_for_pedestrian_values

    @@tag_for_bike_values = ActiveRoad::OsmPbfImporter.tag_for_pedestrian_values + ["cycleway"]
    cattr_reader :tag_for_bike_values

    @@tag_for_train_values = %w{rail tram funicular light_rail subway}
    cattr_reader :tag_for_train_values

    def initialize(xml_file, database_path = "/tmp/osm_pbf.kch")
      @xml_file = xml_file
      @database_path = database_path
    end

    def parser
      @parser ||= PbfParser.new(xml_file)
    end
    
    def kc_batch_size
      @kc_batch_size = 500000
    end

    def batch_size
      @pg_batch_size = 200000
    end

    def progress_bar
      @progress_bar ||= ::ProgressBar.create(:format => '%a |%b>>%i| %p%% %t', :total => 100)
    end

    def database
      @database ||= DB::new
    end
    
    def open_database(path)
      database.open(path, DB::OWRITER | DB::OCREATE)
      database.clear
    end
    
    def close_database
      database.close   
    end

    def authorized_tags
      @authorized_tags ||= ["highway", "railway"]
    end

    # Return an hash with tag_key => tag_value for osm attributes
    def extracted_tags(tags)
      {}.tap do |extracted_tags|
        tags.each do |key, value|
          if authorized_tags.include?(key)
            extracted_tags[key] = value
          end
        end           
      end
    end

    def physical_road_conditionnal_costs(tags)
      [].tap do |prcc|
        tags.each do |tag_key, tag_value|
          if ["highway", "railway"].include?(tag_key)
            prcc << [ "car", Float::MAX] if !ActiveRoad::OsmPbfImporter.tag_for_car_values.include?(tag_value)  
            prcc << [ "pedestrian", Float::MAX] if !ActiveRoad::OsmPbfImporter.tag_for_pedestrian_values.include?(tag_value)
            prcc << [ "bike", Float::MAX] if !ActiveRoad::OsmPbfImporter.tag_for_bike_values.include?(tag_value) 
            prcc << [ "train", Float::MAX] if !ActiveRoad::OsmPbfImporter.tag_for_train_values.include?(tag_value)
          end
        end
      end
    end
    
    # def backup_nodes(database)      
    #   # Process the file until it finds any way.
    #   parser.next until parser.nodes.any?
      
    #   counter = 0
    #   # Once it found at least one way, iterate to find the remaining ways.
    #   until parser.nodes.empty?        
    #     parser.nodes.each do |node|
    #       # Save nodes in kyotocabinet database
    #       counter += 1
    #       database[ node[:id].to_s ] = Marshal.dump(Node.new(node[:id].to_s, node[:lon], node[:lat]))
    #     end

    #     # When there's no more fileblocks to parse, #next returns false
    #     # This avoids an infinit loop when the last fileblock still contains ways
    #     break unless parser.next
    #   end
    # end    

    def update_node_with_way(way, database)
      way_id = way[:id].to_s
      # Get node ids for each way
      node_ids = []
      nodes = way.key?(:refs) ? way[:refs] : [] 
      
      # Take only the first and the last node => the end of physical roads
      nodes.each do |node|       
        node_ids << node.to_s  
      end  

      # Update node data with way id
      node_ids.each_with_index do |id, index|
        database.accept(id) { |key, value|
          node = Marshal.load(value)
          node.add_way(way_id)
          node.end_of_way = true if [nodes.first.to_s, nodes.last.to_s].include?(node.id)
          Marshal.dump(node)
        }
      end
    end

    def way_geometry(way, database)
      # Get node ids for each way
      node_ids = []
      nodes = way.key?(:refs) ? way[:refs] : [] 
      
      # Take only the first and the last node => the end of physical roads
      nodes.each do |node|       
        node_ids << node.to_s  
      end  

      nodes_geometry = []
      node_ids.each do |id|
        node = Marshal.load(database[id])
        nodes_geometry << GeoRuby::SimpleFeatures::Point.from_x_y(node.lon, node.lat, 4326)
      end

      GeoRuby::SimpleFeatures::LineString.from_points(nodes_geometry, 4326) if nodes_geometry.present?    
    end
    
    def iterate_nodes(database)
      junctions_values = []    
      junctions_ways = {}
      # traverse records by iterator
      database.each { |key, value|
        
        node = Marshal.load(value)
        geometry = GeoRuby::SimpleFeatures::Point.from_x_y( node.lon, node.lat, 4326) if( node.lon && node.lat )    
        if node.ways.present? && (node.ways.count >= 2 || node.end_of_way == true )  # Take node with at least two ways or at the end of a way
          junctions_values << [ node.id, geometry ]
          junctions_ways[node.id] = node.ways
        end
        
        if junctions_values.count == pg_batch_size
          save_junctions(junctions_values, junction_ways) 
          #Reset
          junctions_values = []    
          junctions_ways = {}
        end
      }    
      save_junctions(junctions_values, junctions_ways) if junctions_values.present?
    end

    def save_junctions(junctions_values, junctions_ways)
      junction_columns = [:objectid, :geometry]
      # Save junctions in the stack
      ActiveRoad::Junction.import(junction_columns, junctions_values, :validate => false) if junctions_values.present?

      # Link the junction with physical roads
      junctions_ways.each do |junction_objectid, way_objectids|
        junction = ActiveRoad::Junction.find_by_objectid(junction_objectid)
        
        physical_roads = ActiveRoad::PhysicalRoad.find_all_by_objectid(way_objectids)
        junction.physical_roads << physical_roads if physical_roads      
      end
    end

    
    def import
      # process the database by iterator
      # FIX : Want to use DB::OTRUNCATE but it will not create database
      DB::process(database_path, DB::OWRITER | DB::OCREATE) { |database|           
        database.clear
        #backup_nodes(database)

        physical_road_values = []
        attributes_by_objectid = {}

        parser.each do |nodes, ways, relations|
          unless nodes.empty?
            nodes_counter = 0
            nodes_hash = {}
            nodes.each do |node|     
              nodes_hash[ node[:id].to_s ] = Marshal.dump(Node.new(node[:id].to_s, node[:lon], node[:lat]))
              nodes_counter += 1
              
              if nodes_counter > kc_batch_size
                database.set_bulk(nodes_hash)
                nodes_counter = 0
                nodes_hash = {}
              end
            end
            database.set_bulk(nodes_hash) if nodes_hash.present?
          end
          
          unless ways.empty?  
            database.transaction {
              ways.each do |way|
                way_id = way[:id].to_s
                
                if way.key?(:tags)
                  tags = extracted_tags(way[:tags])
                  
                  if tags.present?          
                    update_node_with_way(way, database)
                    
                    spherical_factory = ::RGeo::Geographic.spherical_factory
                    geometry = way_geometry(way, database)
                    length_in_meter = spherical_factory.line_string(geometry.points.collect(&:to_rgeo)).length
                    physical_road_values << [way_id, geometry, length_in_meter]
                    attributes_by_objectid[way_id] = [physical_road_conditionnal_costs(tags)]
                  end
                end
                
                if (physical_road_values.count == pg_batch_size)
                  save_physical_roads_and_children(physical_road_values, attributes_by_objectid)
                  
                  # Reset  
                  physical_road_values = []
                  attributes_by_objectid = {}
                end
              end
            }
          end

          # unless relations.empty?
          #   puts "Je parse les relations"
          # end
        end        

        progress_bar.progress += 30 
        progress_bar.log "Finish to import nodes and ways"
        
        save_physical_roads_and_children(physical_road_values, attributes_by_objectid) if physical_road_values.present? && 
        progress_bar.progress += 40 
        progress_bar.log "Finish to import physical roads"
        

        iterate_nodes(database)          
        progress_bar.progress += 30
        progress_bar.log "Finish to import junctions"  
      }      
    end


    def save_physical_roads_and_children(physical_road_values, attributes_by_objectid = {})
      # Save physical roads
      physical_road_columns = [:objectid, :geometry, :length_in_meter]
      ActiveRoad::PhysicalRoad.import(physical_road_columns, physical_road_values, :validate => false)

      # Save physical road conditionnal costs
      prcc = []
      attributes_by_objectid.each do |objectid, attributes|
        pr = ActiveRoad::PhysicalRoad.where(:objectid => objectid).first

        physical_road_conditionnal_costs = attributes.first
        physical_road_conditionnal_costs.each do |physical_road_conditionnal_cost|
          physical_road_conditionnal_cost.append pr.id
          prcc << physical_road_conditionnal_cost
        end
      end        

      physical_road_conditionnal_cost_columns = [:tags, :cost, :physical_road_id]
      ActiveRoad::PhysicalRoadConditionnalCost.import(physical_road_conditionnal_cost_columns, prcc, :validate => false)               
    end

    
    class Node
      attr_accessor :id, :lon, :lat, :ways, :end_of_way

      def initialize(id, lon, lat, ways = [], end_of_way = false)
        @id = id
        @lon = lon
        @lat = lat
        @ways = ways
        @end_of_way = end_of_way
      end

      def add_way(id)
        @ways << id
      end

      def marshal_dump
        [@id, @lon, @lat, @ways, @end_of_way]
      end
      
      def marshal_load array
        @id, @lon, @lat, @ways, @end_of_way = array
      end
    end
    
  end  
end
