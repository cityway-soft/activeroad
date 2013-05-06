FactoryGirl.define do

  factory :physical_road_conditionnal_cost, :class => ActiveRoad::PhysicalRoadConditionnalCost do
    physical_road
    tags "user"
    cost 0.1  
  end

end
