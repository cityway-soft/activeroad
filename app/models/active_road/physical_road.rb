require "activerecord-postgres-hstore"

module ActiveRoad
  class PhysicalRoad < ActiveRoad::Base
    serialize :tags, ActiveRecord::Coders::Hstore
    attr_accessible :objectid, :kind, :tags, :geometry, :logical_road_id, :length_in_meter, :width

    validates_uniqueness_of :objectid
    validates_presence_of :kind

    has_many :numbers, :class_name => "ActiveRoad::StreetNumber", :inverse_of => :physical_road
    belongs_to :logical_road, :class_name => "ActiveRoad::LogicalRoad"
    has_and_belongs_to_many :junctions, :uniq => true
    has_many :physical_road_conditionnal_costs

    acts_as_geom :geometry => :line_string
    delegate :locate_point, :interpolate_point, :to => :geometry

    before_validation :update_length_in_meter

    def update_length_in_meter
      if ( geometry )
        spherical_factory = ::RGeo::Geographic.spherical_factory  
        self.update_attribute :length_in_meter, spherical_factory.line_string(geometry.points.collect(&:to_rgeo)).length
      end
    end

    %w[max_speed, max_slope].each do |key|
      attr_accessible key
      scope "has_#{key}", lambda { |value| where("properties @> hstore(?, ?)", key, value) }      
      define_method(key) do
        properties && properties[key]
      end
      
      define_method("#{key}=") do |value|
        self.properties = (properties || {}).merge(key => value)
      end
    end
    
    def name
      logical_road.try(:name) or objectid
    end

    alias_method :to_s, :name

    def self.nearest_to(location, distance = 100)
      with_in(location, distance).closest_to(location).first
    end

    def self.closest_to(location)
      location_as_text = location.to_ewkt(false)
      order("ST_Distance(geometry, GeomFromText('#{location_as_text}', 4326))").limit(1)
    end

    def self.with_in(location, distance)
      # FIXME why ST_DWithin doesn't use meters ??
      distance = distance / 1000.0

      location_as_text = location.to_ewkt(false)
      where "ST_DWithin(ST_GeomFromText(?, 4326), geometry, ?)", location_as_text, distance
    end

  end
end
