FactoryGirl.define do  

  factory :junction, :class => ActiveRoad::Junction do
    sequence(:objectid) { |n| "junction::#{n}" }
    geometry GeoRuby::SimpleFeatures::Point.from_x_y(2.2946, 48.8580, ActiveRoad.srid)

    after(:create) do |junction|
      junction.physical_roads = FactoryGirl.create_list(:physical_road, 2)
    end
  end

end

