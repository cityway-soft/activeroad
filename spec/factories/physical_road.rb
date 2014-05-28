FactoryGirl.define do

  factory :physical_road, :class => ActiveRoad::PhysicalRoad do
    sequence(:objectid) { |n| "physical_road::#{n}" }    
    geometry "LINESTRING(3 4,10 50,20 25)"
  end

end
