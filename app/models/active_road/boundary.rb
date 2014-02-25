module ActiveRoad
  class Boundary < ActiveRoad::Base
    #set_table_name :boundaries
    attr_accessible :objectid, :geometry, :name, :admin_level, :postal_code, :insee_code
    acts_as_geom :geometry => :multi_polygon

    # Return linear rings which delimit multi polygon area 
    def self.all_uniq_borders
      borders = self.all.collect(&:geometry).collect(&:polygons).flatten(1).collect(&:rings).flatten(1).uniq
      GeoRuby::SimpleFeatures::MultiLineString.from_line_strings(borders)
    end
    
    # Return linear rings which delimit multi polygon area 
    def borders
      geometry.polygons.collect(&:rings).flatten
    end
    
    # Contains not take object equals on a boundary border!!
    def self.first_contains(other)
      where("ST_Contains(geometry, ST_GeomFromEWKT(E'#{other.as_hex_ewkb}'))").first
    end

    def self.all_intersect(other)
      where("ST_Intersects(geometry, ST_GeomFromEWKT(E'#{other.as_hex_ewkb}'))")
    end
    
    def self.all_intersection(other)
      where("ST_Intersection(geometry, ST_GeomFromEWKT(E'#{other.as_hex_ewkb}'))")
    end
  end  
end
