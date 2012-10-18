class AddTagsPhysicalRoad < ActiveRecord::Migration
  def change
    add_column :physical_roads, :tags, :string
  end
end
