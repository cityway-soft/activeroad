module ActiveRoad
  module OsmPbfImporter
   
    # See for more details :  
    # http://wiki.openstreetmap.org/wiki/FR:France_roads_tagging
    # http://wiki.openstreetmap.org/wiki/FR:Cycleway
    # http://wiki.openstreetmap.org/wiki/Key:railway
    @@tag_for_car_values = %w{motorway trunk trunk_link primary secondary tertiary motorway_link primary_link unclassified service road residential track}
    mattr_reader :tag_for_car_values    
    
    @@tag_for_pedestrian_values = %w{pedestrian footway path steps}
    mattr_reader :tag_for_pedestrian_values
    
    @@tag_for_bike_values = tag_for_pedestrian_values + ["cycleway"]
    mattr_reader :tag_for_bike_values
    
    @@tag_for_train_values = %w{rail tram funicular light_rail subway}
    mattr_reader :tag_for_train_values
    
    @@pg_batch_size = 10000 # Not puts a high value because postgres failed to allocate memory
    mattr_reader :pg_batch_size
    
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
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
            prcc << [ "car", Float::MAX] if !self.tag_for_car_values.include?(tag_value)  
            prcc << [ "pedestrian", Float::MAX] if !self.tag_for_pedestrian_values.include?(tag_value)
            prcc << [ "bike", Float::MAX] if !self.tag_for_bike_values.include?(tag_value) 
            prcc << [ "train", Float::MAX] if !self.tag_for_train_values.include?(tag_value)
          end
        end
      end
    end     

    def way_geometry(way)
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

      GeoRuby::SimpleFeatures::LineString.from_points(nodes_geometry, 4326) if nodes_geometry.present? &&  1 < nodes_geometry.count     
    end   

    def backup_nodes_pgsql(junctions_values = [], junctions_ways = [])    
      junction_columns = [:objectid, :geometry]
      # Save junctions in the stack
      ActiveRoad::Junction.import(junction_columns, junctions_values, :validate => false) if junctions_values.present?
      
      # Link the junction with physical roads
      ActiveRoad::Junction.transaction do 
        junctions_ways.each do |junction_objectid, way_objectids|
          junction = ActiveRoad::Junction.find_by_objectid(junction_objectid)
          
          physical_roads = ActiveRoad::PhysicalRoad.find_all_by_objectid(way_objectids)
          junction.physical_roads << physical_roads if physical_roads      
        end
      end
    end

    # Make the choice to separate postgres backup and kc backup to :
    # - separate treatments
    # - use transaction with kc
    def backup_ways_pgsql
      puts "Begin to backup ways in PostgreSql"
      start = Time.now
      ways_parser = ::PbfParser.new(pbf_file)
      ways_counter = 0 
      physical_road_values = []
      attributes_by_objectid = {}
      
      # Process the file until it finds any way.
      ways_parser.next until ways_parser.ways.any?
      
      # Once it found at least one way, iterate to find the remaining ways.
      until ways_parser.ways.empty?       
        last_way = ways_parser.ways.last
        ways_parser.ways.each do |way|
          ways_counter += 1
          way_id = way[:id].to_s
          
          if way.key?(:tags)
            tags = extracted_tags(way[:tags])
            spherical_factory = ::RGeo::Geographic.spherical_factory
            geometry = way_geometry(way)
            
            if tags.present? && geometry.present?                         
              length_in_meter = spherical_factory.line_string(geometry.points.collect(&:to_rgeo)).length
              physical_road_values << [way_id, geometry, length_in_meter]
              attributes_by_objectid[way_id] = physical_road_conditionnal_costs(tags)
            end
          end
          
          if (physical_road_values.count == @@pg_batch_size || (last_way == way && physical_road_values.present?) )
            save_physical_roads_and_children(physical_road_values, attributes_by_objectid)
            
            # Reset  
            physical_road_values = []
            attributes_by_objectid = {}
          end
        end
        
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains ways
        break unless ways_parser.next
      end                        
      p "Finish to backup #{ways_counter} ways in PostgreSql in #{(Time.now - start)} seconds"      
    end

    def save_physical_roads_and_children(physical_road_values, attributes_by_objectid = {})
      # Save physical roads
      physical_road_columns = [:objectid, :geometry, :length_in_meter]
      ActiveRoad::PhysicalRoad.import(physical_road_columns, physical_road_values, :validate => false)

      # Save physical road conditionnal costs
      prcc = []
      attributes_by_objectid.each do |objectid, physical_road_conditionnal_costs|
        pr = ActiveRoad::PhysicalRoad.where(:objectid => objectid).first

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
