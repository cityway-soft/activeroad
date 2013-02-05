class CreatePhysicalRoads < ActiveRoad::Migration
  def self.up
    create_table :physical_roads do |t|
      t.string :objectid
      t.belongs_to :logical_road
      t.line_string :geometry, :srid => ActiveRoad.srid
      t.timestamps
    end

    add_index :physical_roads, :objectid, :uniq => true
    add_index :physical_roads, :logical_road_id
  end

  def self.down
    drop_table :physical_roads
  end
end
