module ActiveRoad
  class JunctionConditionnalCost < ActiveRoad::Base

    belongs_to :junction

    validates_presence_of :junction_id
    validates_presence_of :tags
    validates_presence_of :cost
    
  end
end
