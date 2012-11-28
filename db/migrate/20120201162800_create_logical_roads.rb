class CreateLogicalRoads < ActiveRoad::Migration
  def self.up
    create_table :logical_roads do |t|
      t.string :name
      t.string :objectid
      t.timestamps
    end

    add_index :logical_roads, :objectid, :uniq => true
    add_index :logical_roads, :name
  end

  def self.down
    if table_exists?(:logical_roads)
      drop_table :logical_roads
    end
  end
end
