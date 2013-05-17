# This class find the shortest path between a departure and an arrival with : 
#   - weight functions
#   - tags to find selected physical roads 
#
# A classic result would be with a point for departure and arrival : 
# Paths ==> 1      : Departure Point
#       |=> 2      : Access Link
#       |=> 3      : Path between AccessPoint and a Junction
#       |=> ...    : Path between a Junction and another Junction 
#       |=> n-2    : Path between a Junction and an Access Point 
#       |=> n-1    : Access Link
#       |=> n      : Arrival Point


require 'shortest_path/finder'

class ActiveRoad::ShortestPath::Finder < ShortestPath::Finder

  attr_accessor :road_kind, :tags, :speed

  def initialize(departure, arrival, tags = {}, speed = 4, road_kind = "road")
    super departure, arrival
    @road_kind = road_kind
    @tags = tags
    @speed = 4000 / 3600 # Convert speed in meter/second
  end

  def visited?(node)
    super(respond_to?(:arrival) ? node.arrival : node)
  end

  def visit(node)
    super(respond_to?(:arrival) ? node.arrival : node)
  end

  def destination_accesses 
    @destination_accesses ||= ActiveRoad::AccessPoint.to(destination, tags, road_kind)
  end

  # Return Shortest distance to go to the node + Distance from node to destination
  def search_heuristic_distance(node)
    shortest_distances[node] + distance_heuristic(node)
  end
  
  def search_heuristic(node)
    shortest_distances[node] + time_heuristic(node)
  end

  def follow_way?(node, destination, weight)
    search_heuristic(node) + weight < time_heuristic(source) * 10
  end

  # Return a time in second from node to destination
  def time_heuristic(node)
    if node.respond_to?(:arrival)
      node.arrival.to_geometry.spherical_distance(destination) / speed
    else
      node.to_geometry.spherical_distance(destination) / speed
    end
  end

  # Return a distance in meter from node to destination
  def distance_heuristic(node)
    if node.respond_to?(:arrival)
      node.arrival.to_geometry.spherical_distance(destination)
    else
      node.to_geometry.spherical_distance(destination)
    end
  end

  # Define weights
  def ways(node)

    paths = 
      if GeoRuby::SimpleFeatures::Point === node
        ActiveRoad::AccessLink.from(node, tags, road_kind)
      else
        node.paths(tags, road_kind)
      end

    unless GeoRuby::SimpleFeatures::Point === node # For the first point to access physical roads
      destination_accesses.select do |destination_access|
        if node.access_to_road?(destination_access.physical_road)
          paths << ActiveRoad::Path.new(:departure => node.arrival, :arrival => destination_access, :physical_road => destination_access.physical_road)
        end
      end
    end    
    
    array = paths.collect do |path|
      [ path, path.respond_to?(:length) ? path.length / speed : 0 ]
    end

    Hash[array]
  end

  def geometry
    @geometry ||= GeoRuby::SimpleFeatures::LineString.merge path.collect { |n| n.to_geometry }.select { |g| GeoRuby::SimpleFeatures::LineString === g }
  end

  # Use to profile code
  def self.example
    from = (ENV['FROM'] or "30.030238,-90.061541")
    to = (ENV['TO'] or "29.991739,-90.06918")
    kind = (ENV['KIND'] or "road")

    ActiveRoad::ShortestPath::Finder.new GeoRuby::SimpleFeatures::Point.from_lat_lng(from), GeoRuby::SimpleFeatures::Point.from_lat_lng(to), kind
  end

end
