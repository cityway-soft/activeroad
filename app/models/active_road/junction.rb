# A junction is a connection between 1 to n physical roads
module ActiveRoad
  class Junction < ActiveRoad::Base
    serialize :tags, ActiveRecord::Coders::Hstore
    attr_accessible :objectid, :tags, :geometry, :height, :waiting_constraint

    validates_uniqueness_of :objectid

    has_and_belongs_to_many :physical_roads, :class_name => "ActiveRoad::PhysicalRoad",:uniq => true
    has_many :junction_conditionnal_costs, :class_name => "ActiveRoad::JunctionConditionnalCost"

    def location_on_road(road)
      (@location_on_road ||= {})[road.id] ||= road.locate_point(geometry)
    end

    def paths
      physical_roads.includes(:junctions, :physical_road_conditionnal_costs).collect do |physical_road|
        ActiveRoad::Path.all self, (physical_road.junctions - [self]), physical_road
      end.flatten
    end

    def access_to_road?(road)
      physical_roads.pluck(:id).include? road.id
    end

    def to_geometry
      geometry
    end

    def to_s
      "Junction @#{geometry.lng},#{geometry.lat}"
    end

    def name
      physical_roads.join(" - ")
    end
  end
end
