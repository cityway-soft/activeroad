Factory.define :physical_road, :class => ActiveRoad::PhysicalRoad do |f|
  f.logical_road
  f.kind "road"
  f.sequence(:objectid) { |n| "physicalroad::#{n}" }
  f.geometry {  rgeo_factory.line_string([rgeo_factory.point(0, 0, ActiveRoad.srid), rgeo_factory.point(1, 1, ActiveRoad.srid)]) }
end
