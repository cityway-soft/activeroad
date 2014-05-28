class ActiveRoad::Base < ActiveRecord::Base
  self.abstract_class = true
  include ActiveRoad::RgeoExt
  
end
