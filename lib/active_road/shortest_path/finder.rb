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

  attr_accessor :speed, :physical_road_filter, :follow_way_filter, :user_weights, :request_conditionnal_costs_linker, :constraints

  def initialize(departure, arrival, speed = 4, constraints = [], follow_way_filter = {})    
    super departure, arrival
    @speed = speed * 1000 / 3600 # Convert speed in meter/second
    @constraints = constraints
    @follow_way_filter = follow_way_filter
  end

  def request_conditionnal_costs_linker
    @request_conditionnal_costs_linker ||= ActiveRoad::RequestConditionnalCostLinker.new(constraints)
  end

  def destination_accesses 
    @destination_accesses ||= ActiveRoad::AccessPoint.to(destination)
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
    
    # Add path weight
    path_weights += path_weight(path.length_in_meter) if path.respond_to?(:length_in_meter)
    
    # Add junction weight if it's a junction with a waiting constraint
    if path.class != GeoRuby::SimpleFeatures::Point && path.departure.class == ActiveRoad::Junction && path.departure && path.departure.waiting_constraint
      path_weights += path.departure.waiting_constraint
    end

    # Add physical road weighy if it's a physical road
    if path.class == ActiveRoad::Path && path.physical_road
      cc_percentage = request_conditionnal_costs_linker.conditionnal_costs_sum(path.physical_road.physical_road_conditionnal_costs)
      path_weights += path_weight(path.length_in_meter, cc_percentage) if path.respond_to?(:length_in_meter)
    end
    
    path_weights
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

  def search_heuristic(node)
    shortest_distances[node] + time_heuristic(node)
  end

  # Update context with uphill, downhill and height
  # TODO : Fix arguments node is not a node but a path a point or an access link!!
  def refresh_context( node, context = {} )
    context_uphill = context[:uphill] ? context[:uphill] : 0
    context_downhill = context[:downhill] ? context[:downhill] : 0
    context_height = context[:height] ? context[:height] : 0

    if( node.class == ActiveRoad::Path )
      departure = node.departure
      physical_road = node.physical_road            

      node_uphill = ( physical_road && physical_road.uphill) ? physical_road.uphill : 0
      node_downhill = (physical_road && physical_road.downhill) ? physical_road.downhill : 0
      node_height = (departure.class != ActiveRoad::AccessPoint && departure && departure.height) ? departure.height : 0
      
      return { :uphill => (context_uphill + node_uphill), :downhill => (context_downhill + node_downhill), :height => (context_height + node_height) }
    else
      return {:uphill => context_uphill, :downhill => context_downhill, :height => context_height}
    end
  end

  # Follow way depends from uphill, downhill, height and heuristics
  def follow_way?(node, destination, weight, context={})
    # Check that arguments in the context is less  than the object parameters    
    request = true
    request = request && context[:uphill] <= follow_way_filter[:uphill] if follow_way_filter[:uphill] && context[:uphill].present?
    request = request && context[:downhill] <= follow_way_filter[:downhill] if follow_way_filter[:downhill] && context[:downhill].present?
    request = request && context[:height] <= follow_way_filter[:height] if follow_way_filter[:height] && context[:height].present?    
    request = request && ( search_heuristic(node) + weight ) < ( time_heuristic(source) * 4 )
  end

  def ways(node, context={})
    paths =
      if GeoRuby::SimpleFeatures::Point === node
        ActiveRoad::AccessLink.from(node)
      else
        node.paths
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
