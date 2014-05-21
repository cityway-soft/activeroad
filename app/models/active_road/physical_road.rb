# -*- coding: utf-8 -*-
module ActiveRoad
  class PhysicalRoad < ActiveRoad::Base
    extend ::Enumerize
    extend ActiveModel::Naming

    attr_accessible :objectid, :tags, :geometry, :logical_road_id, :boundary_id, :length_in_meter, :minimum_width, :covering, :transport_mode, :slope, :cant, :physical_road_type 
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
    belongs_to :boundary, :class_name => "ActiveRoad::Boundary"
    has_and_belongs_to_many :junctions, :uniq => true
    has_many :physical_road_conditionnal_costs

    acts_as_geom :geometry => :line_string
    delegate :locate_point, :interpolate_point, :length, :to => :geometry    

    before_create :update_length_in_meter
    before_update :update_length_in_meter
    def update_length_in_meter
      if geometry.present?
        spherical_factory = ::RGeo::Geographic.spherical_factory  
        self.length_in_meter = spherical_factory.line_string(geometry.points.collect(&:to_rgeo)).length
        #self.length_in_meter = length
      end
    end
    
    def street_name
      logical_road.try(:name) or objectid
    end

    def intersection(other)
      postgis_calculate(:intersection, [self, other])
    end

    def difference(other)
      postgis_calculate(:difference, [self, other])
    end
    
    # distance in srid format 0.001 ~= 111.3 m à l'équateur
    # TODO : Must convert distance in meters => distance in srid
    def self.nearest_to(location, distance = 0.001)
      # FIX Limit to 1 physical roads for perf, must be extended
      pr = all_dwithin(location, distance)
      pr == [] ? [] : [pr.first]
    end

  end
end
