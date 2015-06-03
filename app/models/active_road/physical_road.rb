# -*- coding: utf-8 -*-
module ActiveRoad
  class PhysicalRoad < ActiveRoad::Base
    include RgeoExt::Support
    extend ::Enumerize
    extend ActiveModel::Naming
    acts_as_copy_target
    set_rgeo_factory_for_column(:geometry, RgeoExt.cartesian_factory)
    

    #attr_accessible :objectid, :tags, :geometry, :logical_road_id, :boundary_id, :minimum_width, :covering, :transport_mode, :slope, :cant, :physical_road_type 
    store_accessor :tags
    enumerize :transport_mode, :in => %w["pedestrian", "car", "bike", "train"]
    enumerize :covering, :in => %w[category0, category1, category2, category3, category4, category5, category6, category7, category8, category9 ]
    enumerize :minimum_width, :in => %w[category0, category1, category2, category3, category4, category5, category6, category7, category8, category9 ]
    enumerize :slope, :in => %w[category0, category1, category2, category3, category4, category5, category6, category7, category8, category9 ]
    enumerize :cant, :in => %w[category0, category1, category2, category3, category4, category5, category6, category7, category8, category9 ]
    enumerize :physical_road_type, :in => %w[category0, category1, category2, category3, category4, category5, category6, category7, category8, category9 ]

    validates_uniqueness_of :objectid
    
    belongs_to :logical_road, :class_name => "ActiveRoad::LogicalRoad"
    belongs_to :boundary, :class_name => "ActiveRoad::Boundary"
    has_and_belongs_to_many :junctions, :class_name => "ActiveRoad::Junction"   
    has_many :physical_road_conditionnal_costs
    has_many :numbers, :class_name => "ActiveRoad::StreetNumber", :inverse_of => :physical_road

    delegate :locate_point, :interpolate_point, :to => :geometry    
    
    def street_name
      logical_road.try(:name) or objectid
    end

    def line_substring(percentage_departure, percentage_arrival, is_reversed)
      if percentage_departure == 0 && percentage_arrival == 1
        if is_reversed
          RgeoExt.cartesian_factory.line_string(geometry.points.reverse)
        else
          return geometry
        end
      else
        sql = "ST_Line_Substring(ST_GeomFromEWKT('#{geometry}'), #{percentage_departure}, #{percentage_arrival})"
        sql = is_reversed ? "SELECT ST_Reverse(#{sql})" : "SELECT #{sql}"
        value = ActiveRoad::PhysicalRoad.connection.select_value(sql)
        geometry = value.blank? ? nil : RgeoExt.cartesian_factory.parse_wkb(value)
        return geometry
      end
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
      where("ST_DWithin(geometry, '#{location.as_text}', #{distance})").order("ST_Distance(geometry, '#{location.as_text}')").limit(3)
    end

  end
end
