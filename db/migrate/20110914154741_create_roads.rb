class CreateRoads < ActiveRecord::Migration
  def self.up
    create_table :roads do |t|
      t.string :name
      t.string :objectid
      t.multi_line_string :geometry, :srid => ActiveRoad.srid
      t.timestamps
    end

    add_index :roads, :objectid, :uniq => true
  end

  def self.down
    drop_table :roads
  end
end
