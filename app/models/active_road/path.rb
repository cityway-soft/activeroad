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
        if RGeo::Feature::Point === endpoint
          road.locate_point endpoint
        else
          endpoint.location_on_road road
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

  def geometry_without_cache
    sorted_locations_on_road = locations_on_road.sort
    reverse = (sorted_locations_on_road != locations_on_road)
    value = ActiveRecord::Base.connection.select_value("SELECT ST_Line_Substring(ST_GeomFromEWKT('#{physical_road.geometry}'), #{sorted_locations_on_road.first}, #{sorted_locations_on_road.last})")
    geometry = value.blank? ? nil : geos_factory.parse_wkb(value)
    geometry = @@geos_factory.line_string (geometry.points.reverse) if reverse
    geometry
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
