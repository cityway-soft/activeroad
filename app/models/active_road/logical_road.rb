module ActiveRoad
  class LogicalRoad < ActiveRoad::Base
    extend ActiveSupport::Memoizable
    attr_accessible :objectid, :name

    #validates_uniqueness_of :objectid

    has_many :physical_roads, :class_name => "ActiveRoad::PhysicalRoad", :inverse_of => :logical_road

    has_many :numbers, :through => :physical_roads, :class_name => "ActiveRoad::StreetNumber"

    def geometry
      GeoRuby::SimpleFeatures::MultiLineString.from_line_strings physical_roads.map(&:geometry)
    end

    def at(value)
      if Float === value
        geometry_at_location value
      else
        geometry_at_number value
      end
    end

    def geometry_at_number(number)
      numbers.find_or_initialize_by_number(number.to_s).tap do |number|
        number.road = self
      end.geometry if number.present?
    end
    memoize :geometry_at_number

    def geometry_at_location(location)
      geometry.interpolate_point(location) if geometry
    end

    def self.find_all_by_bounds(bounds)
      ne_corner, sw_corner = bounds.upper_corner, bounds.lower_corner
      sql_box = "SetSRID('BOX3D(#{ne_corner.lng} #{ne_corner.lat}, #{sw_corner.lng} #{sw_corner.lat})'::box3d, #{ActiveRoad.srid})"
      find :all, :conditions => "geometry && #{sql_box}"
    end
  end
end
