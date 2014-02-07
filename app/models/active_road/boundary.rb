module ActiveRoad
  class Boundary < ActiveRoad::Base
    #set_table_name :boundaries
    attr_accessible :objectid, :geometry, :name, :admin_level, :postal_code, :insee_code
    
  end  
end
