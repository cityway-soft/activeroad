module ActiveRoad
  class PhysicalRoadConditionnalCost < ActiveRoad::Base
     belongs_to :physical_road

    validates_presence_of :physical_road_id
    validates_presence_of :tags
    validates_presence_of :cost
    
  end
end
