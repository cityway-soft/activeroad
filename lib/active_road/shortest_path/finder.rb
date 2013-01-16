require 'shortest_path/finder'

class ActiveRoad::ShortestPath::Finder < ShortestPath::Finder

  attr_accessor :road_kind

  # By default, use the GEOS implementation for spatial columns.
  def self.rgeo_factory
    ::RGeo::Geos.factory(:srid => ActiveRoad.srid, :native_interface => :ffi, :wkt_parser => {:support_ewkt => true})   
  end

  def initialize(departure, arrival, road_kind = "road")
    super departure, arrival
    @road_kind = road_kind
  end

  def visited?(node)
    super(respond_to?(:arrival) ? node.arrival : node)
  end

  def visit(node)
    super(respond_to?(:arrival) ? node.arrival : node)
  end

  def destination_accesses
    @destination_accesses ||= ActiveRoad::AccessPoint.to(destination, road_kind)
  end

  def search_heuristic(node)
    shortest_distances[node] + distance_heuristic(node)
  end

  def follow_way?(node, destination, weight)
    search_heuristic(node) + weight < distance_heuristic(source) * 10
  end

  def distance_heuristic(node)
    if node.respond_to?(:arrival)
      node.arrival.to_geometry.distance(destination) # TODO spherical_distance
    else
      node.to_geometry.distance(destination)  # TODO spherical_distance
    end
  end

  def paths(node)
    if RGeo::Geos::FFIPointImpl === node
      ActiveRoad::AccessLink.from(node, road_kind)
    else
      node.paths(road_kind)
    end
  end

  def ways(node)
    # $stderr.puts node
    paths = paths(node)

    unless RGeo::Geos::FFIPointImpl === node
      destination_accesses.select do |destination_access|
        if node.access_to_road?(destination_access.physical_road)
          paths << ActiveRoad::Path.new(:departure => node.arrival, :arrival => destination_access, :physical_road => destination_access.physical_road)
        end
      end
    end

    array = paths.collect do |path|
      [ path, path.respond_to?(:length) ? path.length : 0 ]
    end

    Hash[array]
  end

  def geometry
    @geometry ||= rgeo_factory.line_string path.collect { |n| n.to_geometry }.select { |g| RGeo::Geos::FFILineStringImpl === g }.collect(&:points).flatten
  end

  # Use to profile code
  def self.example
    from = (ENV['FROM'] or "30.030238,-90.061541")
    to = (ENV['TO'] or "29.991739,-90.06918")
    kind = (ENV['KIND'] or "road")

    ActiveRoad::ShortestPath::Finder.new rgeo_factory.point(from), rgeo_factory.point(to), kind
  end

end
