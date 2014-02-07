module ActiveRoad
  module OsmPbfImporter           
    
    @@pg_batch_size = 10000 # Not puts a high value because postgres failed to allocate memory
    mattr_reader :pg_batch_size
    
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
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

    def relation_required_tags_keys
      @relation_required_tags_keys ||= ["boundary", "admin_level"]
    end

    def relation_selected_tags_keys
      @relation_selected_tags_keys ||= ["boundary", "admin_level", "ref:INSEE", "name", "addr:postcode", "type"]
    end
    
    def way_required_tags_keys
      @way_required_tags_keys ||= ["highway", "railway", "boundary"]
    end
    
    def way_selected_tags_keys
      @way_selected_tags_keys ||= [ "name", "maxspeed", "oneway", "boundary", "admin_level" ]
    end

    def way_optionnal_tags_keys
      @way_optionnal_tags_keys ||= ["highway", "bridge", "tunnel", "toll", "cycleway", "cycleway-right", "cycleway-left", "cycleway-both", "oneway:bicycle", "oneway", "boundary", "admin_level"]
    end

    def required_way?(tags)
      way_required_tags_keys.each do |require_tag_key|
        if tags.keys.include?(require_tag_key)
          return true
        end
      end
      return false      
    end
    
    def required_relation?(tags)
      relation_required_tags_keys.each do |require_tag_key|
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

    # def extract_tag_value(tag_value)
    #   case tag_value 
    #   when "yes" : 1 
    #   when "no" : 0
    #   when /[0-9].+/i tag_value.to_f        
    #   else 0    
    #   end     
    # end

    def physical_road_conditionnal_costs(way)
      [].tap do |prcc|        
        prcc << [ "car", Float::MAX] if !way.car
        prcc << [ "pedestrian", Float::MAX] if !way.pedestrian
        prcc << [ "bike", Float::MAX] if !way.bike
        prcc << [ "train", Float::MAX] if !way.train
      end
    end     

    def way_geometry(node_ids)
      nodes_geometry = []
      node_ids.each do |id|
        node = Marshal.load(nodes_database[id])
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

    def backup_ways_pgsql(physical_road_values, attributes_by_objectid = {})
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

    class Way
      attr_accessor :id, :geometry, :nodes, :car, :bike, :train, :pedestrian, :name, :maxspeed, :oneway, :boundary, :admin_level, :options

      def initialize(id, geometry, nodes = [], car = false, bike = false, train = false, pedestrian = false, name = "", maxspeed = 0, oneway = false, boundary = "", admin_level = "", options = {})
        @id = id
        @geometry = geometry
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
        @options = options
      end

      def add_node(id)
        @nodes << id
      end

      def marshal_dump
        [@id, @geometry, @nodes, @car, @bike, @train, @pedestrian, @name, @maxspeed, @oneway, @boundary, @admin_level, @options]
      end
      
      def marshal_load array
        @id, @geometry, @nodes, @car, @bike, @train, @pedestrian, @name, @maxspeed, @oneway, @boundary, @admin_level, @options = array
      end
    end
       
  end  
end
