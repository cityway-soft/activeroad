Factory.define :road, :class => ActiveRoad::Base do |f|
  f.sequence(:name) { |n| "Road #{n}" }
  f.geometry { FactoryGirl.generate :multi_line }
end

module FactoryGirl

  def self.generate_list(name, amount)
    amount.times.map { FactoryGirl.generate name }
  end

end

FactoryGirl.define do
  sequence :point do |n|
    GeoRuby::SimpleFeatures::Point.from_x_y rand(20037508.342789244), rand(20037508.342789244), 900913 # n, n, 900913 # 
  end

  sequence :line do |n|
    GeoRuby::SimpleFeatures::LineString.from_points FactoryGirl.generate_list(:point, 3), 900913
  end

  sequence :multi_line do |n|
    GeoRuby::SimpleFeatures::MultiLineString.from_line_strings FactoryGirl.generate_list(:line, 2), 900913
  end
end

FactoryGirl.define do
  sequence :number_suffix do |n|
    ["", "bis", "ter", "A", "B"].sample
  end

  sequence :number do |n|
    rand(4000).to_i.to_s + FactoryGirl.generate(:number_suffix)
  end
end

Factory.define :street_number, :class => ActiveRoad::StreetNumber do |f|
  f.number { FactoryGirl.generate :number  }  
  f.road
  f.geometry { FactoryGirl.generate :point }
  f.location_on_road { rand }
end
