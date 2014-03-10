class AddTagsToStreetNumber < ActiveRecord::Migration
  def change
    add_column :street_numbers, :tags, :hstore
  end
end
