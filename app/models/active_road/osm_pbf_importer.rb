module ActiveRoad
  module OsmPbfImporter   
    
    @@relation_required_tags_keys = ["boundary", "admin_level"]      
    @@relation_selected_tags_keys = ["boundary", "admin_level", "ref:INSEE", "name", "addr:postcode", "type"]
    mattr_reader :relation_required_tags_keys
    mattr_reader :relation_selected_tags_keys
    
    @@way_required_tags_keys = ["highway", "railway", "boundary", "admin_level"]    
    @@way_selected_tags_keys = [ "name", "maxspeed", "oneway", "boundary", "admin_level" ]
    # Add first_node_id and last_node_id
    @@way_optionnal_tags_keys = ["highway", "bridge", "tunnel", "toll", "cycleway", "cycleway-right", "cycleway-left", "cycleway-both", "oneway:bicycle", "oneway", "bicycle", "segregated", "foot", "lanes", "lanes:forward", "lanes:forward:bus", "busway:right", "busway:left", "oneway_bus", "boundary", "admin_level"]
    mattr_reader :way_required_tags_keys
    mattr_reader :way_selected_tags_keys
    mattr_reader :way_optionnal_tags_keys

    @@nodes_selected_tags_keys = [ "addr:housenumber" ]
    mattr_reader :nodes_selected_tags_keys
    
    @@pg_batch_size = 10000 # Not Rails.logger.debug a high value because postgres failed to allocate memory
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

    def required_way?(tags)
      @@way_required_tags_keys.each do |require_tag_key|
        if tags.keys.include?(require_tag_key)
          return true
        end
      end
      return false      
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

    def backup_nodes_pgsql(junctions_values = [])    
      junction_columns = [:objectid, :geometry]
      # Save junctions in the stack
      ActiveRoad::Junction.import(junction_columns, junctions_values, :validate => false) if junctions_values.present?     
    end

    def backup_street_numbers_pgsql(street_number_values = [])    
      street_number_columns = [:objectid, :geometry, :number]
      # Save street_numbers in the stack
      ActiveRoad::StreetNumber.import(street_number_columns, street_number_values, :validate => false) if street_number_values.present?     
    end   

    def backup_ways_pgsql(physical_road_values)
      # Save physical roads
      physical_road_columns = [:objectid, :car, :bike, :train, :pedestrian, :name, :length_in_meter, :geometry, :boundary_id, :tags]

      ActiveRoad::PhysicalRoad.import(physical_road_columns, physical_road_values.map{ |prv| prv.values_at(:objectid, :car, :bike, :train, :pedestrian, :name, :length_in_meter, :geometry, :boundary_id, :tags) }, :validate => false)      

      physical_road_conditionnal_costs = []
      physical_road_from_junction = {}
      
      physical_roads = ActiveRoad::PhysicalRoad.where(:objectid => physical_road_values.map{ |physical_road_value| physical_road_value[:objectid] })
      
      physical_road_values.each do |physical_road_value|
        physical_road = physical_roads.where(:objectid => physical_road_value[:objectid]).first

        # Prepare data to save junctions by batch
        physical_road_values.each do |physical_road_value|
          physical_road_value[:junctions].each do |node_id|
            physical_road_from_junction[node_id] = physical_road.id 
          end
        end
        
        # Prepare data to save conditionnal costs by batch
        physical_road_conditionnal_costs += physical_road_value[:conditionnal_costs].collect{ |cc| cc + [physical_road.id] } if physical_road_value[:conditionnal_costs]
      end
      
      junctions = ActiveRoad::Junction.where(:objectid => physical_road_from_junction.keys)
      junctions_physical_roads = []
      junctions.each do |junction|
        junctions_physical_roads << [physical_road_from_junction[junction.objectid], junction.id]
      end               

      # Save junctions
      junction_physical_road_columns = [:physical_road_id, :junction_id]
      ActiveRoad::JunctionsPhysicalRoad.import(junction_physical_road_columns, junctions_physical_roads, :validate => false)

      # Save physical road conditionnal costs
      physical_road_conditionnal_cost_columns = [:tags, :cost, :physical_road_id]
      ActiveRoad::PhysicalRoadConditionnalCost.import(physical_road_conditionnal_cost_columns, physical_road_conditionnal_costs, :validate => false)

    end

    def backup_logical_roads_pgsql
      Rails.logger.debug "Begin to backup logical roads in PostgreSql"
      start = Time.now

      ActiveRoad::PhysicalRoad.find_in_batches(batch_size: 2000) do |group|
        ActiveRoad::LogicalRoad.transaction do 
          group.each do |physical_road|
            # TODO : use geographical data to know if it's the same logical road or not        
            logical_road = ActiveRoad::LogicalRoad.where(["name = :name AND boundary_id = :boundary_id", {:name => physical_road.name ? physical_road.name : "", :boundary_id => physical_road.boundary_id} ]).first_or_create! do |logical_road|
              logical_road.name = physical_road.name ? physical_road.name : ""
              logical_road.boundary_id = physical_road.boundary_id
              logical_road.physical_roads << physical_road              
            end if physical_road.boundary_id.present?
          end
        end
      end
      Rails.logger.debug "Finish to backup logical roads in PostgreSql in #{(Time.now - start)} seconds"      
    end

    def extract_relation_polygon(outer_geometries, inner_geometries = [])      
      outer_rings = join_ways(outer_geometries)
      inner_rings = join_ways(inner_geometries)      
      GeoRuby::SimpleFeatures::Polygon.from_linear_rings( outer_rings + inner_rings )
    end

    def join_ways(ways)
      closed_ways = []
      endpoints_to_ways = EndpointToWayMap.new
      for way in ways
        if way.closed?
          closed_ways << way
          next
        end
        
        # Are there any existing ways we can join this to?
        to_join_to = endpoints_to_ways.get_from_either_end(way)
        if to_join_to.present?
          joined = way
          for existing_way in to_join_to
            joined = join_way(joined, existing_way)
            endpoints_to_ways.remove_way(existing_way)
            if joined.closed?
              closed_ways << joined
              break
            end
          end

          if !joined.closed?
            endpoints_to_ways.add_way(joined)
          end
        else
          endpoints_to_ways.add_way(way)
        end
      end

      if endpoints_to_ways.number_of_endpoints != 0
        raise StandardError, "Unclosed boundaries"
      end
      
      closed_ways         
    end

    def join_way(way, other)
      if way.closed?
        raise StandardError, "Trying to join a closed way to another"
      end
      if other.closed?
        raise StandardError, "Trying to join a way to a closed way"
      end
      
      if way.points.first == other.points.first
        new_points = other.reverse.points[0..-2] + way.points
      elsif way.points.first == other.points.last
        new_points = other.points[0..-2] + way.points
      elsif way.points.last == other.points.first
        new_points = way.points[0..-2] + other.points
      elsif way.points.last == other.points.last
        new_points = way.points[0..-2] + other.reverse.points
      else
        raise StandardError, "Trying to join two ways with no end point in common"
      end

      GeoRuby::SimpleFeatures::LineString.from_points(new_points)
    end

    class EndpointToWayMap
      attr_accessor :endpoints

      def initialize
        @endpoints = {}
      end

      def add_way(way)
        if get_from_either_end(way).present?
          raise StandardError, "Call to add_way would overwrite existing way(s)"
        end
        self.endpoints[way.points.first] = way
        self.endpoints[way.points.last] = way
      end

      def remove_way(way)
        endpoints.delete(way.points.first)
        endpoints.delete(way.points.last)
      end      

      def get_from_either_end(way)        
        [].tap do |selected_end_points|
          selected_end_points << endpoints[way.points.first] if endpoints.include?(way.points.first)
          selected_end_points << endpoints[way.points.last] if endpoints.include?(way.points.last)
        end
      end
      
      def number_of_endpoints
        return endpoints.size
      end
      
    end
    
    class Node
      attr_accessor :id, :lon, :lat, :ways, :end_of_way, :addr_housenumber

      def initialize(id, lon, lat, addr_housenumber = "", ways = [], end_of_way = false )
        @id = id
        @lon = lon
        @lat = lat
        @addr_housenumber = addr_housenumber
        @ways = ways
        @end_of_way = end_of_way
      end

      def add_way(id)
        @ways << id
      end

      def marshal_dump
        [@id, @lon, @lat, @addr_housenumber, @ways, @end_of_way]
      end
      
      def marshal_load array
        @id, @lon, @lat, @addr_housenumber, @ways, @end_of_way = array
      end

      def used?
        ( ways.present? && ways.size > 1 ) || end_of_way
      end
    end

    class Way
      attr_accessor :id, :nodes, :car, :bike, :train, :pedestrian, :name, :maxspeed, :oneway, :boundary, :admin_level, :options

      def initialize(id, nodes = [], car = false, bike = false, train = false, pedestrian = false, name = "", maxspeed = 0, oneway = false, boundary = "", admin_level = "", options = {})
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
        @options = options
      end

      def add_node(id)
        @nodes << id
      end

      def marshal_dump
        [@id, @nodes, @car, @bike, @train, @pedestrian, @name, @maxspeed, @oneway, @boundary, @admin_level, @options]
      end
      
      def marshal_load array
        @id, @nodes, @car, @bike, @train, @pedestrian, @name, @maxspeed, @oneway, @boundary, @admin_level, @options = array
      end
    end
       
  end  
end
