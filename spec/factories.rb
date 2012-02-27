Factory.define :logical_road, :class => ActiveRoad::LogicalRoad do |f|
  f.sequence(:objectid) { |n| "test::#{n}" }
  f.sequence(:name) { |n| "Road #{n}" }
end

Factory.define :physical_road, :class => ActiveRoad::PhysicalRoad do |f|
  f.logical_road
  f.sequence(:objectid) { |n| "test::#{n}" }
  f.geometry { FactoryGirl.generate :line }
end

FactoryGirl.define do
  factory :junction, :class => ActiveRoad::Junction do |f|
    sequence(:objectid) { |n| "test::#{n}" }
    geometry { FactoryGirl.generate :point }

    # ignore do
    #   physical_road_count 2
    # end

    # after_create do |junction, evaluator|
    #   while junction.physical_roads.size < evaluator.physical_road_count
    #     junction.physical_roads << FactoryGirl.create(:physical_road)
    #   end
    # end
  end
end

module FactoryGirl

  def self.generate_list(name, amount)
    amount.times.map { FactoryGirl.generate name }
  end

end

FactoryGirl.define do
  sequence :point do |n|
    tour_eiffel = GeoRuby::SimpleFeatures::Point.from_x_y(2.2946, 48.8580)
    GeoRuby::SimpleFeatures::Point.from_x_y tour_eiffel.x + (2*rand-1), tour_eiffel.y + (2*rand-1), ActiveRoad.srid
  end

  sequence :line do |n|
    GeoRuby::SimpleFeatures::LineString.from_points FactoryGirl.generate_list(:point, 3), ActiveRoad.srid
  end
end

FactoryGirl.define do
  sequence :number_suffix do |n|
    #["", "bis", "ter", "A", "B"].sample
    ""
  end

  sequence :number do |n|
    rand(4000).to_i.to_s + FactoryGirl.generate(:number_suffix)
  end
end

Factory.define :street_number, :class => ActiveRoad::StreetNumber do |f|
  f.number { FactoryGirl.generate :number  }  
  f.physical_road
  f.geometry { FactoryGirl.generate :point }
  f.location_on_road { rand }
end
