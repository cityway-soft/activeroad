class CreateJunctionsPhysicalRoadsIndexes < ActiveRecord::Migration
  def up
    add_index :junctions_physical_roads, :junction_id
  end

  def down
    remove_index :junctions_physical_roads, :junction_id
  end
end
