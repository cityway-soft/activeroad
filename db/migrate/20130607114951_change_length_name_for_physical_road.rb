class ChangeLengthNameForPhysicalRoad < ActiveRecord::Migration
  def up
    remove_column :physical_roads, :length
    add_column :physical_roads, :length_in_meter, :float, :default => 0
  end

  def down
    remove_column :physical_roads, :length_in_meter
    add_column :physical_roads, :length, :integer
  end
end
