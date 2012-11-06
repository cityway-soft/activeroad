Factory.define :physical_road, :class => ActiveRoad::PhysicalRoad do |f|
  f.logical_road
  f.kind "road"
  f.sequence(:objectid) { |n| "physicalroad::#{n}" }
  f.geometry {  GeoRuby::SimpleFeatures::LineString.from_points [GeoRuby::SimpleFeatures::Point.from_x_y(0, 0, ActiveRoad.srid), GeoRuby::SimpleFeatures::Point.from_x_y(1, 1, ActiveRoad.srid)] }
end
