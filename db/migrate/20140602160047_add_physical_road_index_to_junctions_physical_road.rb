class AddPhysicalRoadIndexToJunctionsPhysicalRoad < ActiveRecord::Migration
  def change
    add_index :junctions_physical_roads, [:physical_road_id]
  end
end
