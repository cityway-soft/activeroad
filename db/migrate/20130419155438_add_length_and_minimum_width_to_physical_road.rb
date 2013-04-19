class AddLengthAndMinimumWidthToPhysicalRoad < ActiveRecord::Migration
  def change
    add_column :physical_roads, :length, :integer, :default => 0
    add_column :physical_roads, :minimum_width, :integer, :default => 0    
  end
end
