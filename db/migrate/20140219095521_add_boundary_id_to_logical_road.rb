class AddBoundaryIdToLogicalRoad < ActiveRecord::Migration
  def change
    add_column :logical_roads, :boundary_id, :integer
  end
end
