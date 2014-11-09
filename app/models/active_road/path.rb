# A path is a link between differents objects : 
#  - Departure
#  - Arrival
class ActiveRoad::Path
  include ActiveRoad::RgeoExt
  
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

  def locations_on_road    
    [departure, arrival].collect do |endpoint|
      location =
        if ActiveRoad::AccessPoint === endpoint
          road.locate_point endpoint.geometry
        else
          endpoint.location_on_road road
          #ActiveRoad::JunctionsPhysicalRoad.where(:physical_road_id => physical_road.id, :junction_id => endpoint.id).first.percentage_location
        end
        
      location = [0, [location, 1].min].max
    end
  end

  def length
    @length ||= if RGeo::Feature::LineString === geometry                  
                  geometry.length
                else                  
                  0
                end
  end

  def self.all(departure, arrivals, physical_road)
    Array(arrivals).collect do |arrival|
      new :departure => departure, :arrival => arrival, :physical_road => physical_road
    end
  end

  delegate :access_to_road?, :to => :arrival

  def paths
    arrival.paths - [reverse]
  end

  def reverse
    self.class.new :departure => arrival, :arrival => departure, :physical_road => physical_road
  end

  def geometry_without_cache2
    points =  physical_road.geometry.points
    points_selected = []

    if ActiveRoad::AccessPoint === departure || ActiveRoad::AccessPoint === arrival
      sorted_locations_on_road = locations_on_road.sort    
      reverse = (sorted_locations_on_road != locations_on_road)
      
      if sorted_locations_on_road == [0, 1]
        if reverse
          return @@geos_factory.line_string(physical_road.geometry.points.reverse)
        else
          return physical_road.geometry
        end
      end
      
      sql = "ST_Line_Substring(ST_GeomFromEWKT('#{physical_road.geometry}'), #{sorted_locations_on_road.first}, #{sorted_locations_on_road.last})"
      sql = reverse ? "SELECT ST_Reverse(#{sql})" : "SELECT #{sql}"
      value = ar_connection.select_value(sql)
      return geometry = value.blank? ? nil : @@geos_factory.parse_wkb(value)      
    end
    
    departure_index = points.index(departure.geometry)
    arrival_index = points.index(arrival.geometry)
    
    if departure_index < arrival_index
      points_selected = points[arrival_index..departure_index]
    elsif arrival_index < departure_index
      points_selected = points.reverse![arrival_index..departure_index]
    else
      raise StandardError, "Junction is not on the physical road"
    end

    @@geos_factory.line_string(points)
  end
  
  def geometry_without_cache        
    sorted_locations_on_road = locations_on_road.sort    
    reverse = (sorted_locations_on_road != locations_on_road)
    
    if sorted_locations_on_road == [0, 1]
      if reverse
        return @@geos_factory.line_string(physical_road.geometry.points.reverse)
      else
        return physical_road.geometry
      end
    end

    sql = "ST_Line_Substring(ST_GeomFromEWKT('#{physical_road.geometry}'), #{sorted_locations_on_road.first}, #{sorted_locations_on_road.last})"
    sql = reverse ? "SELECT ST_Reverse(#{sql})" : "SELECT #{sql}"
    value = ar_connection.select_value(sql)
    geometry = value.blank? ? nil : @@geos_factory.parse_wkb(value)
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
