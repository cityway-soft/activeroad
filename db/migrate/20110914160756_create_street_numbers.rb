class CreateStreetNumbers < ActiveRecord::Migration
  def self.up
    create_table :street_numbers do |t|
      t.string :number
      t.float :location_on_road
      t.belongs_to :road
      t.point :geometry, :srid => 900913
      t.timestamps
    end

    add_index :street_numbers, [:number, :road_id]
    add_index :street_numbers, :road_id
  end

  def self.down
    drop_table :street_numbers
  end
end
