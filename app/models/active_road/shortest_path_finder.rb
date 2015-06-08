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

module ActiveRoad
  class ShortestPathFinder < ShortestPath::Finder

    attr_accessor :speed, :user_weights, :request_conditionnal_costs_linker, :constraints, :thresholds, :steps

    def initialize(departure, arrival, speed = 4, constraints = {}, thresholds = {})    
      super departure, arrival
      @speed = speed * 1000 / 3600 # Convert speed in meter/second
      @constraints = constraints
      @thresholds = thresholds
      @steps = 0
    end

    def request_conditionnal_costs_linker
      @request_conditionnal_costs_linker ||= ActiveRoad::RequestConditionnalCostLinker.new(constraints)
    end

    def destination_accesses 
      @destination_accesses ||= ActiveRoad::AccessPoint.to(destination)
    end

    def destination_geography
      @destination_geography ||= RgeoExt.geographical_factory.point(destination.x, destination.y)
    end

    # Return a time in second from node to destination
    # TODO : Tenir compte de la sinuosité de la route???
    def time_heuristic(node)
      if node.respond_to?(:arrival)
        if RGeo::Feature::Point === node.arrival # When access to arrival
          node_geometry = node.arrival
        else
          node_geometry = node.arrival.geometry
        end
      else
        node_geometry = node # When access from departure
      end

      node_geography = RgeoExt.geographical_factory.point(node_geometry.x, node_geometry.y)
      node_geography.distance(destination_geography) / speed
    end

    def time_heuristic_from_source 
      @time_heuristic_from_source ||= time_heuristic(source)
    end

    # Return a distance in meter from node to destination
    # def distance_heuristic(node)
    #   if node.respond_to?(:arrival)
    #     node.arrival.geometry.spherical_distance(destination)
    #   else
    #     node.geometry.spherical_distance(destination)
    #   end
    # end

    def path_weights(path)
      path_weights = 0
      
      # Add path weight
      path_weights += path_weight(path.length) if path.respond_to?(:length)
      
      # Add junction weight if it's a junction with a waiting constraint
      if !(RGeo::Feature::Point === path)  && ActiveRoad::Junction === path.departure && path.departure.waiting_constraint
        path_weights += path.departure.waiting_constraint
      end

      # Add physical road weight if it's a physical road
      physical_road = path.physical_road if ActiveRoad::Path === path

      if physical_road && request_conditionnal_costs_linker.unauthorized_constraints_intersection_with?(physical_road)
        path_weights = Float::INFINITY
      end
      
      path_weights
    end 
    
    def path_weight( length = 0, percentage = 1 )
      (length / speed) * percentage
    end

    def geometries
      # Delete departure and arrival
      path.pop
      path.shift
      
      path.collect(&:geometry)
    end
    
    def geometry
      @geometry ||= if path.present?
                      # Must use compact to delete nil from RGeo::Feature::Point in geometries
                      g = geometries.collect{ |g| g.points if RGeo::Feature::LineString === g }.compact.flatten
                      RgeoExt.cartesian_factory.line_string( g )
                    end
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

      if( ActiveRoad::Path === node )
        departure = node.departure
        physical_road = node.physical_road            

        node_uphill = ( physical_road && physical_road.uphill) ? physical_road.uphill : 0
        node_downhill = (physical_road && physical_road.downhill) ? physical_road.downhill : 0
        node_height = ( !(ActiveRoad::AccessPoint === departure) && departure && departure.height) ? departure.height : 0
        
        return { :uphill => (context_uphill + node_uphill), :downhill => (context_downhill + node_downhill), :height => (context_height + node_height) }
      else
        return {:uphill => context_uphill, :downhill => context_downhill, :height => context_height}
      end
    end

    # Follow way depends from uphill, downhill, height and heuristics
    def follow_way?(node, destination, weight, context={})
      # Check that arguments in the context is less  than the object parameters    
      request = true
      request = request && context[:uphill] <= thresholds[:uphill] if thresholds[:uphill] && context[:uphill].present?
      request = request && context[:downhill] <= thresholds[:downhill] if thresholds[:downhill] && context[:downhill].present?
      request = request && context[:height] <= thresholds[:height] if thresholds[:height] && context[:height].present?    
      request = request && ( search_heuristic(node) + weight ) < ( time_heuristic_from_source * 4 )
    end
    
    def ways(node, context={})    
      paths = if RGeo::Feature::Point === node
                # Search access to physical roads for departure
                ActiveRoad::AccessLink.from(node)
              else
                node.paths
              end
      
      # Search for each node if they have physical roads in common with arrival
      # If true finish the trip and link to arrival
      unless RGeo::Feature::Point === node 
        destination_accesses.select do |destination_access|        
          if node.access_to_road?(destination_access.physical_road)
            paths << ActiveRoad::Path.new(:departure => node.arrival, :arrival => destination_access, :physical_road => destination_access.physical_road)
          end
        end
      end

      # puts "_______________"
      # puts "     STEP #{@steps} from node #{node.name if node.respond_to?(:name) }      "
      # puts "_______________"
      # paths.each do |path|
      #   puts "#{path.name if path.respond_to?(:name) } with weight #{path_weights(path)}"
      # end

      array = paths.collect do |path|
        [ path, path_weights(path)]
      end       

      @steps += 1
      
      Hash[array]
    end

  end
end
