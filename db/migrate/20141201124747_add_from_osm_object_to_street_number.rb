class AddFromOsmObjectToStreetNumber < ActiveRecord::Migration
  def change
    add_column :street_numbers, :from_osm_object, :string
  end
end
