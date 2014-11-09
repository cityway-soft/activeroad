module ActiveRoad
  class JunctionsPhysicalRoad < ActiveRoad::Base
    belongs_to :junction
    belongs_to :physical_road
  end
end
