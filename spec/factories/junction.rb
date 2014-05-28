FactoryGirl.define do  

  factory :junction, :class => ActiveRoad::Junction do
    sequence(:objectid) { |n| "junction::#{n}" }
    geometry "POINT(6 10)"
  end

  factory :junction_with_physical_roads, :class => ActiveRoad::Junction do
    sequence(:objectid) { |n| "junction_with_physical_roads::#{n}" }
    geometry "POINT(6 10)"

    after(:create) do |junction|
      junction.physical_roads = FactoryGirl.create_list(:physical_road, 2)
    end
  end

end

