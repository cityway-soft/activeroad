# A junction is a connection between 1 to n physical roads
module ActiveRoad
  class Junction < ActiveRoad::Base
    store_accessor :tags
    #attr_accessible :objectid, :tags, :geometry, :height, :waiting_constraint
    set_rgeo_factory_for_column(:geometry, @@geos_factory)
    
    validates_uniqueness_of :objectid

    has_many :physical_roads, :through => :junctions_physical_roads, :class_name => "ActiveRoad::PhysicalRoad"
    has_many :junctions_physical_roads
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

    def to_s
      "Junction @#{geometry.x},#{geometry.y}"
    end

    def name
      physical_roads.join(" - ")
    end
  end
end
