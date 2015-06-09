# A junction is a connection between 1 to n physical roads
module ActiveRoad
  class Junction < ActiveRoad::Base
    include RgeoExt::Support
    acts_as_copy_target
    store_accessor :tags
    #attr_accessible :objectid, :tags, :geometry, :height, :waiting_constraint
    set_rgeo_factory_for_column(:geometry, RgeoExt.cartesian_factory)

    validates_uniqueness_of :objectid

    has_and_belongs_to_many :physical_roads, :class_name => "ActiveRoad::PhysicalRoad"
    has_many :junction_conditionnal_costs, :class_name => "ActiveRoad::JunctionConditionnalCost"

    def location_on_road(road)
      (@location_on_road ||= {})[road.id] ||= road.locate_junction(geometry)
    end

    def paths_without_cache
      physical_roads.flat_map do |physical_road|
        ActiveRoad::Path.all( self, (physical_road.junctions - [self]), physical_road )
      end
    end

    def self.load_cache
      includes(physical_roads: [{ junctions: :physical_roads }, :physical_road_conditionnal_costs]).find_each(&:paths)
    end

    @@enable_cache_paths = false
    cattr_accessor :enable_cache_paths

    @@cache = {}
    def paths_with_cache
      @@cache[id] ||= paths_without_cache
    end

    def paths
      enable_cache_paths ? paths_with_cache : paths_without_cache
    end

    def access_to_road?(road)
      @access_to_road ||= physical_roads.map(&:id).include? road.id
    end

    def to_s
      "Junction @#{geometry.x},#{geometry.y}"
    end

    def name
      physical_roads.join(" - ")
    end
  end
end
