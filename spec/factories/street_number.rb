Factory.define :street_number, :class => ActiveRoad::StreetNumber do |f|
  f.sequence(:objectid) { |n| "streetnumber::#{n}" }
  f.number { rand(4000).to_i.to_s }  
  f.physical_road
  f.geometry {  GeoRuby::SimpleFeatures::Point.from_x_y(2.2946, 48.8580, ActiveRoad.srid) }
  f.location_on_road { rand }
end
