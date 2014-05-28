FactoryGirl.define do  

  factory :street_number, :class => ActiveRoad::StreetNumber do
    sequence(:objectid) { |n| "streetnumber::#{n}" }
    number { rand(4000).to_i.to_s }  
    physical_road
    geometry "POINT(6 10)"
    location_on_road { rand }
  end

end
