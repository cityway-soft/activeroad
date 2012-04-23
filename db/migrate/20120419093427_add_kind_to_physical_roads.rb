class AddKindToPhysicalRoads < ActiveRecord::Migration
  def change
    add_column :physical_roads, :kind, :string

    ActiveRoad::PhysicalRoad.reset_column_information
    ActiveRoad::PhysicalRoad.update_all :kind => "road"

    add_index :physical_roads, :kind
  end
end
