FactoryGirl.define do

  factory :junction_conditionnal_cost, :class => ActiveRoad::JunctionConditionnalCost do
    association :junction
    tags "user"
    cost 0.1  
    after(:create) do |jcc|
      jcc.start_physical_road = jcc.junction.physical_roads.first
      jcc.end_physical_road = jcc.junction.physical_roads.last
    end
  end

end
