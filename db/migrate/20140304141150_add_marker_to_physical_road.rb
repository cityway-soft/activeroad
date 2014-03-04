class AddMarkerToPhysicalRoad < ActiveRecord::Migration
  def change
    add_column :physical_roads, :marker, :integer, :default => 0
  end
end
