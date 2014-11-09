module ActiveRoad
  class LogicalRoad < ActiveRoad::Base
    #attr_accessible :objectid, :name, :boundary_id

    has_many :physical_roads, :class_name => "ActiveRoad::PhysicalRoad", :inverse_of => :logical_road
    has_many :numbers, :through => :physical_roads, :class_name => "ActiveRoad::StreetNumber"
    belongs_to :boundary, :class_name => "ActiveRoad::Boundary"

    #validates_uniqueness_of :objectid
    validates :boundary, presence: true

    def geometry
      @@geos_factory.multi_line_string physical_roads.map(&:geometry)
    end

    def at(value)
      if Float === value
        geometry_at_location value
      else
        geometry_at_number value
      end
    end

    def geometry_at_number(number)
      @geometry_at_number ||= numbers.find_or_initialize_by_number(number.to_s).tap do |number|
        number.road = self
      end.geometry if number.present?
    end

    def geometry_at_location(location)
      value =  ActiveRecord::Base.connection.select_value("SELECT ST_Line_Interpolate_Point(ST_GeomFromEWKT('#{self.geometry}'), #{location} )")		
      value.blank? ? nil : @@geos_factory.parse_wkb(value)
    end

    def self.find_all_by_bounds(bounds)
      ne_corner, sw_corner = bounds.upper_corner, bounds.lower_corner
      sql_box = "SetSRID('BOX3D(#{ne_corner.lng} #{ne_corner.lat}, #{sw_corner.lng} #{sw_corner.lat})'::box3d, #{ActiveRoad.srid})"
      find :all, :conditions => "geometry && #{sql_box}"
    end
  end
end
