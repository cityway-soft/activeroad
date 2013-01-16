Factory.define :junction, :class => ActiveRoad::Junction do |f|
  f.sequence(:objectid) { |n| "junction::#{n}" }
  f.geometry { rgeo_factory.point(2.2946, 48.8580, ActiveRoad.srid) }
end

Factory.define :junction_linked, :parent => :junction do |f|
  f.after_build do |junction|
    2.times do
      junction.physical_roads << Factory(:physical_road)
    end
  end
end
