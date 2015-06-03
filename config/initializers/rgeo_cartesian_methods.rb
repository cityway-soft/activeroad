module RGeo

  module Cartesian

    module LineStringMethods
      
      def locate_point(target)
        # Hack to return a location for linestring with departure equals arrival
        return 0 if length == 0
        distance_on_line(target) / length
      end

      def distance_on_line(target)
        nearest_locator = nearest_locator(target)
        nearest_locator.distance_on_segment + distance_from_departure_to_segment(nearest_locator.segment)
      end

      def distance_from_departure_to_segment(segment)
        index = _segments.index(segment) 
        _segments[0...index].inject(0.0){ |sum_, seg_| sum_ + seg_.length }
      end

      def nearest_locator(target)
        locators(target).min_by(&:distance_from_segment)
      end

      def locators(point)
        _segments.collect { |segment| segment.locator(point) }
      end

      def interpolate_point(location)
        return points.last if location >= 1
        return points.first if location <= 0

        distance_on_line_string = location * length

        line_distance_at_departure = line_distance_at_arrival = 0
        segment = _segments.find do |segment|
          line_distance_at_arrival += segment.length
          line_distance_at_departure = line_distance_at_arrival - segment.length
          line_distance_at_arrival > distance_on_line_string
        end

        return nil if segment.blank?
        
        location_on_segment = (distance_on_line_string - line_distance_at_departure) / segment.length
        dx_location, dy_location = segment.dx * location_on_segment, segment.dy * location_on_segment
        factory.point(segment.s.x + dx_location, segment.s.y + dy_location)
      end

    end
    
    class Segment

      attr_reader :lensq

      def locator(target)
        PointLocator.new target, self
      end

    end

    class PointLocator
      include Math

      attr_reader :target, :segment
      
      def initialize(target, segment)
        @target = target
        @segment = segment
        raise "Target is not defined" unless target
      end

      def distance_on_segment        
        return 0 if segment.length == 0
        scalar_product / segment.length
      end

      def distance_from_segment
        if segment.contains_point?(target)
          0
        elsif segment.s == segment.e
          segment.s.distance(target)
        else
          sin_angle * target_distance_from_departure
        end
      end

      def scalar_product
        ( target.x - segment.s.x)*(segment.e.x - segment.s.x) + (target.y - segment.s.y)*(segment.e.y - segment.s.y )
      end

      def angle
        acos cos_angle
      end
      
      def sin_angle
        sin angle
      end
      
      def cos_angle
        [-1, [1, (scalar_product / segment.length / target_distance_from_departure)].min].max
      end

      def target_distance_from_departure        
        segment.s.distance target
      end

    end

  end

end
