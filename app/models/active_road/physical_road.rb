module ActiveRoad
  class PhysicalRoad < ActiveRoad::Base
    validates_uniqueness_of :objectid

    has_many :numbers, :class_name => "ActiveRoad::StreetNumber", :inverse_of => :physical_road

    belongs_to :logical_road, :class_name => "ActiveRoad::LogicalRoad"

    has_and_belongs_to_many :junctions, :uniq => true

    acts_as_geom :geometry => :line_string

    delegate :locate_point, :interpolate_point, :length, :to => :geometry

    def name
      logical_road.try(:name) or objectid
    end

    alias_method :to_s, :name

  end
end
