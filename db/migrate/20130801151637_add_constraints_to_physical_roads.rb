class AddConstraintsToPhysicalRoads < ActiveRecord::Migration
  def up
    remove_column :physical_roads, :minimum_width
    remove_column :physical_roads, :kind
    
    add_column :physical_roads, :minimum_width, :string
    add_column :physical_roads, :transport_mode, :string
    add_column :physical_roads, :uphill, :float
    add_column :physical_roads, :downhill, :float
    add_column :physical_roads, :slope, :string
    add_column :physical_roads, :cant, :string
    add_column :physical_roads, :covering, :string
    add_column :physical_roads, :steps_count, :integer
    add_column :physical_roads, :banisters_available, :boolean
    add_column :physical_roads, :tactile_band, :boolean
    add_column :physical_roads, :physical_road_type, :string

    add_index :physical_roads, :physical_road_type

  end

  def down       
    remove_column :physical_roads, :minimum_width
    remove_column :physical_roads, :transport_mode
    remove_column :physical_roads, :uphill
    remove_column :physical_roads, :downhill
    remove_column :physical_roads, :slope
    remove_column :physical_roads, :cant
    remove_column :physical_roads, :covering
    remove_column :physical_roads, :steps_count
    remove_column :physical_roads, :banisters_available
    remove_column :physical_roads, :tactile_band
    remove_column :physical_roads, :physical_road_type

    add_column :physical_roads, :minimum_width, :integer
  end
end
