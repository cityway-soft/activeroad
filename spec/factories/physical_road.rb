FactoryGirl.define do

  factory :physical_road, :class => ActiveRoad::PhysicalRoad do
    sequence(:objectid) { |n| "physicalroad::#{n}" }
    logical_road
    geometry {  GeoRuby::SimpleFeatures::LineString.from_points [GeoRuby::SimpleFeatures::Point.from_x_y(0, 0, ActiveRoad.srid), GeoRuby::SimpleFeatures::Point.from_x_y(1, 1, ActiveRoad.srid)] }
  end

end
