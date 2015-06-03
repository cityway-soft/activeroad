# A path is a link between differents objects :
#  - Departure
#  - Arrival
module ActiveRoad
  class Path
    include RgeoExt::Support
    attr_accessor :departure, :arrival, :physical_road
    alias_method :road, :physical_road

    def initialize(attributes = {})
      attributes.each do |k, v|
        send("#{k}=", v)
      end
    end

    def name
      "Path : #{departure} -> #{arrival}"
    end

    # def position_in_road_geometry(projected_point, points)
    #   if points.include?(projected_point)
    #     return points.index(projected_point)
    #   end

    #   last_point = points.last
    #   points.each_with_index do |point, index|
    #     if point == last_point
    #       raise StandardError, "Point #{projected_point} not found on the road #{road.id}"
    #     end

    #     next_point = points[index + 1]
    #     if ( points  projected_point
    #   end
    # end

    # Return an array of points ordered from departure to arrival
    # def ordered_points
    #   road_start_point = road.geometry.start_point
    #   road_end_point = road.geometry.end_point
    #   road_points = road.geometry.points
    #   ordered_points = []

    #   # Get points from interpolated departure or arrival to interpolated departure or arrival in physical roads if one endpoint is an access point

    #   if ActiveRoad::AccessPoint === departure || ActiveRoad::AccessPoint === arrival
    #     sorted_locations_on_road = locations_on_road.sort
    #     reverse = (sorted_locations_on_road != locations_on_road)

    #     if sorted_locations_on_road == [0, 1]
    #       if reverse
    #         return road_points.reverse
    #       else
    #         return road_points
    #       end
    #     end

    #     sql = "ST_Line_Substring(ST_GeomFromEWKT('#{physical_road.geometry}'), #{sorted_locations_on_road.first}, #{sorted_locations_on_road.last})"
    #     sql = reverse ? "SELECT ST_Reverse(#{sql})" : "SELECT #{sql}"
    #     value = ActiveRoad::PhysicalRoad.connection.select_value(sql)
    #     if !value.blank?
    #       geometry = RgeoExt.cartesian_factory.parse_wkb(value)
    #       if RGeo::Feature::LineString === geometry
    #         ordered_points = geometry.points
    #       else # Delete point when path departure == arrival
    #         ordered_points = []
    #       end
    #     else
    #       ordered_points = []
    #     end

    #     return ordered_points
    #   end

    #   # Get points from departure to arrival in physical roads if endpoints are junctions
    #   departure_index = road_points.index(departure.geometry)
    #   arrival_index = road_points.index(arrival.geometry)

    #   if departure_index < arrival_index
    #     ordered_points = road_points[departure_index..arrival_index]
    #   elsif arrival_index < departure_index
    #     ordered_points = road_points[arrival_index..departure_index].reverse
    #   else
    #     raise StandardError, "Junction is not on the physical road"
    #   end

    #   ordered_points
    # end

    # Build a geometry form ordered points
    def geometry_without_cache
      sorted_locations_on_road = locations_on_road.sort
      is_reversed = (sorted_locations_on_road != locations_on_road)
      geometry = road.line_substring(sorted_locations_on_road.first, sorted_locations_on_road.last, is_reversed)
    end

    def locations_on_road
      @locations_on_road ||= [departure, arrival].collect do |endpoint|
        location =
          if ActiveRoad::AccessPoint === endpoint
            road.locate_point endpoint.geometry
          else
            endpoint.location_on_road road
          end

        location = [0, [location, 1].min].max
      end
    end

    # def length
    #   @length ||= if RGeo::Feature::LineString === geometry
    #                 RgeoExt.geographical_factory.line_string(geometry.points).length
    #               else
    #                 0
    #               end
    # end

    def length
      @length ||= length_on_road * road.length
    end

    def length_on_road
      begin_on_road, end_on_road = locations_on_road.sort
      end_on_road - begin_on_road
    end

    def self.all(departure, arrivals, physical_road)
      Array(arrivals).collect do |arrival|
        new :departure => departure, :arrival => arrival, :physical_road => physical_road
      end
    end

    delegate :access_to_road?, :to => :arrival

    # Delete reverse path but not other paths found on the same physical_road
    #
    #  <-                My path               ->
    #  X-------------------X--------------------[X]------------------X
    #                       <-     Path used   -> <-   Path used   ->
    #  <-           Path deleted               ->
    def paths
      arrival.paths - [reverse]
    end

    def reverse
      self.class.new :departure => arrival, :arrival => departure, :physical_road => physical_road
    end

    def geometry_with_cache
      @geometry ||= geometry_without_cache
    end
    alias_method :geometry, :geometry_with_cache

    def to_s
      name
    end

    def ==(other)
      [:departure, :arrival, :physical_road].all? do |attribute|
        other.respond_to?(attribute) and send(attribute) == other.send(attribute)
      end
    end
    alias_method :eql?, :==

    def hash
      [departure, arrival, physical_road].hash
    end

  end
end
