class ChangeTagsTypeForJunction < ActiveRecord::Migration
  def up
    remove_column :junctions, :tags
    add_column :junctions, :tags, :hstore
  end

  def down
    add_column :junctions, :tags, :string
  end
end
