class CreateJunctions < ActiveRoad::Migration
  def self.up
    create_table :junctions do |t|
      t.string :objectid
      t.point :geometry, :srid => ActiveRoad.srid
      t.timestamps
    end

    add_index :junctions, :objectid, :uniq => true

    create_table :junctions_physical_roads, :id => false do |t|
      t.belongs_to :physical_road
      t.belongs_to :junction
    end

    # Generated name is too long for PostgreSQL
    add_index :junctions_physical_roads, [:physical_road_id, :junction_id], :name => 'junctions_physical_roads_ids', :uniq => true
  end

  def self.down
    drop_table :junctions
    drop_table :junctions_physical_roads
  end
end
