class ChangeTagsTypeForPhysicalRoad < ActiveRecord::Migration
  def up
    remove_column :physical_roads, :tags
    add_column :physical_roads, :tags, :hstore
  end

  def down
    add_column :physical_roads, :tags, :string
  end
end
