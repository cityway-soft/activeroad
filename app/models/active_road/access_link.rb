class ActiveRoad::AccessLink

  attr_accessor :departure, :arrival

  def initialize(attributes = {})
    attributes.each do |k, v|
      send("#{k}=", v)
    end
  end

  def name
    "#{departure} -> #{arrival}"
  end

  alias_method :to_s, :name

  def self.from(location, kind = "road")
    ActiveRoad::AccessPoint.from(location, kind).collect do |access_point|
      new :departure => location, :arrival => access_point
    end
  end

  def length
    @length ||= departure.to_geometry.distance arrival.to_geometry # TODO spherical_distance
  end

  def geometry
    @geometry ||= rgeo_factory.line_string [departure.to_geometry, arrival.to_geometry]
  end
  alias_method :to_geometry, :geometry

  delegate :access_to_road?, :to => :arrival

  def paths(kind = "roads")
    arrival.respond_to?(:paths) ? arrival.paths(kind) : [arrival]
  end

  def access_to_road?(road)
    arrival.respond_to?(:access_to_road?) ? arrival.access_to_road?(road) : false
  end

end
