# -*- coding: utf-8 -*-
module ActiveRoad
  class PhysicalRoad < ActiveRoad::Base
    extend ::Enumerize
    extend ActiveModel::Naming
    acts_as_copy_target
    set_rgeo_factory_for_column(:geometry, RgeoExt.geos_factory)
    

    #attr_accessible :objectid, :tags, :geometry, :logical_road_id, :boundary_id, :minimum_width, :covering, :transport_mode, :slope, :cant, :physical_road_type 
    store_accessor :tags

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
    has_many :junctions, :through => :junctions_physical_roads, :class_name => "ActiveRoad::Junction"
    has_many :junctions_physical_roads
    
    has_many :physical_road_conditionnal_costs
    
    def street_name
      logical_road.try(:name) or objectid
    end

    def locate_point(point)
      value =  ActiveRecord::Base.connection.select_value("SELECT ST_Line_Locate_Point('#{self.geometry}', '#{point}')")
      value.blank? ? nil : value.to_f
    end

    def interpolate_point(fraction)
      value =  ActiveRecord::Base.connection.select_value("SELECT ST_Line_Interpolate_Point('#{self.geometry}', #{fraction} )")		
      value.blank? ? nil : RgeoExt.geos_factory.parse_wkb(value)
    end
    
    def intersection(other)
      st_intersection other
    end

    def difference(other)
      st_difference other
    end
    
    # distance in srid format 0.001 ~= 111.3 m à l'équateur
    # TODO : Must convert distance in meters => distance in srid
    def self.nearest_to(location, distance = 0.001)
      # FIX Limit to 1 physical roads for perf, must be extended
      pr = st_dwithin(location, distance)
      pr == [] ? [] : [pr.first]
    end

    def self.st_dwithin(other, margin=1)
      where "ST_DWithin(geometry, '#{other.as_text}', #{margin})"
    end

  end
end
