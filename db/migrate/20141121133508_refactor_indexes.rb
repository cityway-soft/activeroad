class RefactorIndexes < ActiveRecord::Migration
  def up
    remove_index :physical_roads, :physical_road_type
    
    add_index :physical_roads, :name
    add_index :physical_roads, :boundary_id
    add_index :logical_roads, :boundary_id
    add_index :junctions, :geometry, :spatial => true
    add_index :street_numbers, :geometry, :spatial => true
  end

  def down
    add_index :physical_roads, :physical_road_type
    
    remove_index :physical_roads, :name
    remove_index :physical_roads, :boundary_id
    remove_index :logical_roads, :boundary_id
    remove_index :junctions, :geometry
    remove_index :street_numbers, :geometry
  end
end
