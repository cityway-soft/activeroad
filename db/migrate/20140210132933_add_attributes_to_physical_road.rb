class AddAttributesToPhysicalRoad < ActiveRecord::Migration
  def change
    add_column :physical_roads, :car, :boolean
    add_column :physical_roads, :bike, :boolean
    add_column :physical_roads, :train, :boolean
    add_column :physical_roads, :pedestrian, :boolean
    add_column :physical_roads, :name, :string    
  end
end
