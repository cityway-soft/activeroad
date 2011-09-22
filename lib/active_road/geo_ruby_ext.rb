require 'geo_ruby'
require 'active_support/memoizable'
require 'active_support/core_ext/module/delegation'

class GeoRuby::SimpleFeatures::MultiLineString

  alias_method :lines, :geometries

  def locate_point(target)
    nearest_locator = nearest_locator(target)
    nearest_locator.location + nearest_locator.index
  end

  def interpolate_point(location)
    line_index, line_location = location.to_i, location % 1
    lines[line_index].interpolate_point(line_location)
  end

  def nearest_locator(target)
    locators(target).min_by(&:distance_from_line)
  end

  def locators(point)
    [].tap do |locators|
      lines.each_with_index do |line, index| 
        locators << PointLocator.new(point, line, index) 
      end
    end
  end

  class PointLocator

    attr_reader :target, :line, :index

    def initialize(target, line, index)
      @target = target
      @line = line
      @index = index
    end

    def location
      line.locate_point(target)
    end

    def distance_on_line
      line.distance_on_line(target)
    end

    def distance_from_line
      line.distance_from_line(target)
    end

  end

end

class GeoRuby::SimpleFeatures::LineString

  def locate_point(target)
    distance_on_line(target) / distance
  end

  def distance_on_line(target)
    nearest_locator = nearest_locator(target)
    nearest_locator.distance_on_segment + nearest_locator.segment.line_distance_at_departure
  end

  def distance_from_line(target)
    nearest_locator(target).distance_from_segment
  end

  def nearest_locator(target)
    locators(target).min_by(&:distance_from_segment)
  end

  def locators(point)
    segments.collect { |segment| segment.locator(point) }
  end

  def segments
    previous_point = nil
    distance_from_departure = 0

    points.inject([]) do |segments, point|
      Segment.new(previous_point, point).tap do |segment|
        segment.line = self
        segment.line_distance_at_departure = segments.sum(&:distance)
        
        segments << segment
      end if previous_point
      
      previous_point = point
      segments
    end
  end

  def distance
    segments.sum(&:distance)
  end

  def interpolate_point(location)
    return points.last if location >= 1
    return points.first if location <= 0

    distance_on_line = location * distance

    segment = segments.find do |segment|
      segment.line_distance_at_arrival > distance_on_line
    end

    location_on_segment =
      (distance_on_line - segment.line_distance_at_departure) / segment.distance

    segment.interpolate_point location_on_segment
  end

  class Segment

    attr_reader :departure, :arrival
    
    def initialize(departure, arrival)
      @departure, @arrival = departure, arrival
    end

    attr_accessor :line, :line_distance_at_departure

    def line_distance_at_arrival
      line_distance_at_departure + distance
    end

    def locator(target)
      PointLocator.new target, self
    end

    def location_in_line
      if line and line_distance_at_departure
        line_distance_at_departure / line.distance
      end
    end

    def square_of_distance
      (arrival.x - departure.x)**2 + (arrival.y - departure.y)**2
    end

    def distance
      departure.euclidian_distance(arrival)
    end

    def to_s
      "#{departure.x},#{departure.y}..#{arrival.x},#{arrival.y}"
    end

    def interpolate_point(location)
      dx, dy = 
        (arrival.x - departure.x)*location, (arrival.y - departure.y)*location
      GeoRuby::SimpleFeatures::Point.from_x_y departure.x + dx, departure.y + dy, line.srid
    end

  end

  class PointLocator
    extend ActiveSupport::Memoizable
    include Math

    attr_reader :target, :segment
    delegate :departure, :arrival, :to => :segment
    
    def initialize(target, segment_or_departure, arrival = nil)
      @segment = 
        if arrival
          Segment.new(segment_or_departure, arrival)
        else
          segment_or_departure
        end
      @target = target

      raise "Target is not defined" unless target
    end

    def distance_from_segment
      sin_angle * target_distance_from_departure
    end

    def distance_on_segment
      # like cos_angle * target_distance_from_departure
      # scalar_product / square_of_segment_distance
      scalar_product / segment_distance
    end

    def locate_point
      scalar_product / square_of_segment_distance
    end

    def scalar_product
      (target.x-departure.x)*(arrival.x-departure.x) + (target.y-departure.y)*(arrival.y-departure.y).to_f
    end
    memoize :scalar_product

    def angle
      acos cos_angle
    end

    def sin_angle
      sin angle
    end

    def cos_angle
      scalar_product / segment_distance / target_distance_from_departure
    end

    def square_of_segment_distance
      (arrival.x - departure.x)**2 + (arrival.y - departure.y)**2
    end
    memoize :square_of_segment_distance

    def segment_distance
      sqrt square_of_segment_distance
    end

    def target_distance_from_departure
      sqrt((target.x - departure.x)**2 + (target.y - departure.y)**2)
    end

  end

end
