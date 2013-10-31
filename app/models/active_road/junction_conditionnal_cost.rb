module ActiveRoad
  class JunctionConditionnalCost < ActiveRoad::Base

    belongs_to :junction
    belongs_to :start_physical_road, :class_name => 'ActiveRoad::PhysicalRoad', :foreign_key => 'start_physical_road_id'
    belongs_to :end_physical_road, :class_name => 'ActiveRoad::PhysicalRoad', :foreign_key => 'end_physical_road_id'

    validates_presence_of :junction_id
    validates_presence_of :tags
    validates_uniqueness_of :tags
    validates_presence_of :cost
    
  end
end
