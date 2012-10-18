class AddTagsJunction < ActiveRecord::Migration
  def change
    add_column :junctions, :tags, :string
  end
end
