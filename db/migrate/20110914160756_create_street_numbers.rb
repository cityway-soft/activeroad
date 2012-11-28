class CreateStreetNumbers < ActiveRoad::Migration
  def self.up
    create_table :street_numbers do |t|
      t.string :number
      t.float :location_on_road
      t.belongs_to :physical_road
      t.point :geometry, :srid => ActiveRoad.srid
      t.timestamps
    end

    add_index :street_numbers, [:number, :physical_road_id]
    add_index :street_numbers, :physical_road_id
  end

  def self.down
    if table_exists?(:street_numbers)
      drop_table :street_numbers
    end
  end
end
