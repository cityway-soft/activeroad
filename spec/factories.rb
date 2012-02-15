Factory.define :logical_road, :class => ActiveRoad::LogicalRoad do |f|
  f.sequence(:objectid) { |n| "test::#{n}" }
  f.sequence(:name) { |n| "Road #{n}" }
end

Factory.define :physical_road, :class => ActiveRoad::PhysicalRoad do |f|
  f.logical_road
  f.sequence(:objectid) { |n| "test::#{n}" }
  f.geometry { FactoryGirl.generate :line }
end

module FactoryGirl

  def self.generate_list(name, amount)
    amount.times.map { FactoryGirl.generate name }
  end

end

FactoryGirl.define do
  sequence :point do |n|
    # TODO use random lat/lng ...
    GeoRuby::SimpleFeatures::Point.from_x_y rand(20037508.342789244), rand(20037508.342789244), ActiveRoad.srid
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
