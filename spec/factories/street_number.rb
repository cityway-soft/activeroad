FactoryGirl.define do  

  factory :street_number, :class => ActiveRoad::StreetNumber do
    sequence(:objectid) { |n| "streetnumber::#{n}" }
    number { rand(4000).to_i.to_s }  
    physical_road
    geometry {  GeoRuby::SimpleFeatures::Point.from_x_y(2.2946, 48.8580, ActiveRoad.srid) }
    location_on_road { rand }
  end

end
