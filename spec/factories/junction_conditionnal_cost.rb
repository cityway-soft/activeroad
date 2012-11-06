Factory.define :junction_conditionnal_cost, :class => ActiveRoad::JunctionConditionnalCost do |f|
  f.association :junction, :factory => :junction_linked
  f.tags "user"
  f.cost 0.1  
  f.after_build do |jcc|
    jcc.start_physical_road = jcc.junction.physical_roads.first
    jcc.end_physical_road = jcc.junction.physical_roads.last
  end
end
