class ActiveRoad::Access

  attr_accessor :location, :physical_road

  def initialize(attributes = {})
    attributes.each do |k, v|
      send("#{k}=", v)
    end
  end

  def self.to(location)
    # TODO find really several roads
    physical_roads = [ ActiveRoad::PhysicalRoad.closest_to location ]

    physical_roads.collect do |physical_road|
      new :location => location, :physical_road => physical_road
    end
  end

  # def access_to_road?(road)
  #   self.physical_road == road
  # end

  def location_on_road
    @location_on_road ||= physical_road.locate_point location
  end

  def point_on_road
    @point_on_road ||= physical_road.interpolate_point(location_on_road)
  end

  def paths
    ActiveRoad::Path.all arrival, physical_road.junctions, physical_road
  end

  # delegate :to_lat_lng, :to => :location

  def name
    "Access on #{physical_road} (@#{location.to_lat_lng})"
  end

  # FIXME returns the point on the road
  def arrival
    point_on_road
  end

  # FIXME returns the real distance
  def length
    @length ||= location.spherical_distance arrival
  end

  def to_s
    name
  end
end
