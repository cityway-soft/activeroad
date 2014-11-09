module ActiveRoad
  class JunctionsPhysicalRoad < ActiveRoad::Base
    acts_as_copy_target
    
    belongs_to :junction
    belongs_to :physical_road
  end
end
