class AddBoundaryIdToPhysicalRoad < ActiveRecord::Migration
  def change
    add_column :physical_roads, :boundary_id, :integer
  end
end
