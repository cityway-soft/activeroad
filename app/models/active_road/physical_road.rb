module ActiveRoad
  class PhysicalRoad < ActiveRoad::Base
    extend ::Enumerize
    extend ActiveModel::Naming

    attr_accessible :objectid, :tags, :geometry, :logical_road_id, :length_in_meter, :minimum_width, :covering, :transport_mode, :slope, :cant, :physical_road_type 
    serialize :tags, ActiveRecord::Coders::Hstore

    # TODO : Pass covering in array mode???
    enumerize :covering, :in => [:slippery_gravel, :gravel, :asphalt_road, :asphalt_road_damaged, :pavement, :irregular_pavement, :slippery_pavement]

    enumerize :minimum_width, :in => [:wide, :enlarged, :narrow, :cramped], :default => :wide
    enumerize :slope, :in => [:flat, :medium, :significant, :steep], :default => :flat
    enumerize :cant, :in => [:flat, :medium, :significant, :steep], :default => :flat
    enumerize :physical_road_type, :in => [:path_link, :stairs, :crossing], :default => :path_link    

    validates_uniqueness_of :objectid

    has_many :numbers, :class_name => "ActiveRoad::StreetNumber", :inverse_of => :physical_road
    belongs_to :logical_road, :class_name => "ActiveRoad::LogicalRoad"
    has_and_belongs_to_many :junctions, :uniq => true
    has_many :physical_road_conditionnal_costs

    acts_as_geom :geometry => :line_string
    delegate :locate_point, :interpolate_point, :to => :geometry    

    before_create :update_length_in_meter
    before_update :update_length_in_meter
    def update_length_in_meter
      if geometry.present?
        spherical_factory = ::RGeo::Geographic.spherical_factory  
        self.length_in_meter = spherical_factory.line_string(geometry.points.collect(&:to_rgeo)).length
      end
    end
    
    def name
      logical_road.try(:name) or objectid
    end

    alias_method :to_s, :name

    def self.nearest_to(location, distance = 100)
      # FIX Limit to 2 physical roads for perf, must be extended
      with_in(location, distance).closest_to(location).limit(2).includes(:junctions, :physical_road_conditionnal_costs)
    end

    def self.closest_to(location)
      location_as_text = location.to_ewkt(false)
      order("ST_Distance(geometry, ST_GeomFromText('#{location_as_text}', 4326))")
    end

    def self.with_in(location, distance = 100)
      # FIXME why ST_DWithin doesn't use meters ??
      distance = distance / 1000.0

      location_as_text = location.to_ewkt(false)
      where "ST_DWithin(ST_GeomFromText(?, 4326), geometry, ?)", location_as_text, distance
    end

  end
end
