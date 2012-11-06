Factory.define :physical_road_conditionnal_cost, :class => ActiveRoad::PhysicalRoadConditionnalCost do |f|
  f.physical_road
  f.tags "user"
  f.cost 0.1  
end
