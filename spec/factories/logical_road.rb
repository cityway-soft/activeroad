FactoryGirl.define do

  factory :logical_road, :class => ActiveRoad::LogicalRoad do
    sequence(:objectid) { |n|  "logicalroad::#{n}" }
    sequence(:name) { |n|  "Road #{n}" }
  end

end
