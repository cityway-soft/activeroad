Factory.define :logical_road, :class => ActiveRoad::LogicalRoad do |f|
  f.sequence(:objectid) { |n| "logicalroad::#{n}" }
  f.sequence(:name) { |n| "Road #{n}" }
end
