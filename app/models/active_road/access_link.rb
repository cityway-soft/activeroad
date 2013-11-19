class ActiveRoad::AccessLink

  attr_accessor :departure, :arrival

  def initialize(attributes = {})
    attributes.each do |k, v|
      send("#{k}=", v)
    end
  end

  def name
    "AccessLink : #{departure} -> #{arrival}"
  end

  alias_method :to_s, :name

  def self.from(location)
    ActiveRoad::AccessPoint.from(location).collect do |access_point|
      new :departure => location, :arrival => access_point
    end
  end

  def length
    @length ||= departure.to_geometry.spherical_distance arrival.to_geometry
  end
  # TODO Delete this hack due to postgis adapter in physical road
  alias_method :length_in_meter, :length 

  def geometry
    @geometry ||= GeoRuby::SimpleFeatures::LineString.from_points [departure.to_geometry, arrival.to_geometry]
  end
  alias_method :to_geometry, :geometry

  delegate :access_to_road?, :to => :arrival

  def paths
    arrival.respond_to?(:paths) ? arrival.paths : [arrival]
  end

  def access_to_road?(road)
    arrival.respond_to?(:access_to_road?) ? arrival.access_to_road?(road) : false
  end

end
