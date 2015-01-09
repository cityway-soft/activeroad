class AddLengthToPhysicalRoad < ActiveRecord::Migration
  def change
    add_column :physical_roads, :length, :float, :default => 0
    remove_column :physical_roads, :length_in_meter
  end
end
