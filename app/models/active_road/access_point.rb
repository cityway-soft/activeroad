# Access Point is a projection from an origin point on a Physical Road
# This origin point and Access Point are linked by an Access Link  

class ActiveRoad::AccessPoint

  attr_accessor :location, :physical_road, :exit
  alias_method :exit?, :exit

  def initialize(attributes = {})
    attributes.each do |k, v|
      send("#{k}=", v)
    end
  end

  # Find access points from a location
  def self.from(location, forbidden_tags = {})
    # TODO find really several roads
    physical_roads = []
    physical_roads_filtered = ActiveRoad::PhysicalRoadFilter.new(forbidden_tags).filter
    physical_roads << physical_roads_filtered.nearest_to(location, 100) if physical_roads_filtered.present?

    physical_roads.collect do |physical_road|
      new :location => location, :physical_road => physical_road
    end
  end
  
  # Find access points to go to a location
  def self.to(location, forbidden_tags = {})
    # TODO find really several roads
    physical_roads = []
    physical_roads_filtered = ActiveRoad::PhysicalRoadFilter.new(forbidden_tags).filter
    physical_roads << physical_roads_filtered.nearest_to(location) if physical_roads_filtered.present?
    physical_roads.collect do |physical_road|
      new :location => location, :physical_road => physical_road, :exit => true
    end
  end

  def location_on_road(road = nil)
    @location_on_road ||= physical_road.locate_point location
  end

  def point_on_road
    @point_on_road ||= physical_road.interpolate_point location_on_road
  end

  def access_to_road?(road)
    physical_road == road
  end

  def name
    "Access on #{physical_road.objectid} @#{point_on_road.to_lat_lng} (for @#{location.to_lat_lng})"
  end

  def to_geometry
    point_on_road
  end

  delegate :spherical_distance, :to => :point_on_road

  def to_s
    name
  end

  def paths(forbidden_tags = {})
    unless exit?
      ActiveRoad::Path.all self, physical_road.junctions, physical_road
    else
      [ActiveRoad::AccessLink.new(:departure => self, :arrival => location)]
    end
  end

end
