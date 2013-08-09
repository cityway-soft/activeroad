# -*- coding: utf-8 -*-
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

  attr_accessor :speed, :constraints, :user_weights

  def initialize(departure, arrival, speed = 4, constraints = {}, user_weights = {})
    super departure, arrival
    @speed = speed * 1000 / 3600 # Convert speed in meter/second
    @constraints = constraints 
    @user_weights = user_weights # Not used
  end

  def destination_accesses 
    @destination_accesses ||= ActiveRoad::AccessPoint.to(destination, constraints)
  end  

  # Return a time in second from node to destination
  # TODO : Tenir compte de la sinuosité de la route???
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

  def path_weights(path)
    path_weights = 0
    if path.respond_to?(:length_in_meter)    
      path_length = path.length_in_meter
      
      # TODO Refactor user weights
      # if path.respond_to?(:road) # PhysicalRoad only no AccessLink
      #   path_tags = path.road.tags

      #   user_weights.each do |key, value|
      #     if path_tags.keys.include? key
      #       min, max, percentage = value[0], value[1], value[2]
      #       if min <= path_tags[key].to_i && path_tags[key].to_i <= max
      #         path_weights += path_weight(path_length, percentage)
      #       end                    
      #     end
      #   end
      # end

      # Add node weight if it's a junction
     
      # Add time value by default
      path_weights += path_weight(path_length)
    end
    
    path_weights
  end
  
  # TODO
  def node_weight()
  end
  
  def path_weight( length_in_meter = 0, percentage = 1 )
    (length_in_meter / speed) * percentage    
  end
  
  def geometry
    @geometry ||= GeoRuby::SimpleFeatures::LineString.merge path.collect { |n| n.to_geometry }.select { |g| GeoRuby::SimpleFeatures::LineString === g }
  end

  # Use to profile code
  def self.example
    from = (ENV['FROM'] or "30.030238,-90.061541")
    to = (ENV['TO'] or "29.991739,-90.06918")

    ActiveRoad::ShortestPath::Finder.new GeoRuby::SimpleFeatures::Point.from_lat_lng(from), GeoRuby::SimpleFeatures::Point.from_lat_lng(to)
  end

  #-----------------------------------------
  # Overwrite ShortestPath::Finder methods
  #-----------------------------------------
  
  def visited?(node)
    super(respond_to?(:arrival) ? node.arrival : node)
  end

  def visit(node)
    super(respond_to?(:arrival) ? node.arrival : node)
  end

  # Ressaut + dénivellé
  def follow_way?(node, destination, weight)
    search_heuristic(node) + weight < time_heuristic(source) * 10
  end

  def search_heuristic(node)
    shortest_distances[node] + time_heuristic(node)
  end

  # Define weights
  def ways(node)

    paths = 
      if GeoRuby::SimpleFeatures::Point === node
        ActiveRoad::AccessLink.from(node, constraints)
      else
        node.paths(constraints)
      end

    unless GeoRuby::SimpleFeatures::Point === node # For the first point to access physical roads
      destination_accesses.select do |destination_access|
        if node.access_to_road?(destination_access.physical_road)
          paths << ActiveRoad::Path.new(:departure => node.arrival, :arrival => destination_access, :physical_road => destination_access.physical_road)
        end
      end
    end    
    
    array = paths.collect do |path|
      [ path, path_weights(path)]
    end

    Hash[array]
  end

end
