module ActiveRoad
  class Boundary < ActiveRoad::Base
    #set_table_name :boundaries
    attr_accessible :objectid, :geometry, :name, :admin_level, :postal_code, :insee_code
    acts_as_geom :geometry => :multi_polygon

    # Contains not take object equals on a boundary border!!
    def self.first_contains(other)
      find(:first, :conditions => "ST_Contains(geometry, ST_GeomFromEWKT(E'#{other.as_hex_ewkb}'))")
    end
    
    def self.all_intersect(other)
      find(:all, :conditions => "ST_Intersects(geometry, ST_GeomFromEWKT(E'#{other.as_hex_ewkb}'))")
    end
  end  
end
