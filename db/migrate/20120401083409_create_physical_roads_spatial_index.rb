class CreatePhysicalRoadsSpatialIndex < ActiveRecord::Migration
  def up
    add_index :physical_roads, :geometry, :spatial => true
  end

  def down
    remove_index :physical_roads, :geometry, :spatial => true
  end
end
