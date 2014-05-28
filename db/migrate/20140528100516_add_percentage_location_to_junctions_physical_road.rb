class AddPercentageLocationToJunctionsPhysicalRoad < ActiveRecord::Migration
  def change
    add_column :junctions_physical_roads, :percentage_location, :float
  end
end
