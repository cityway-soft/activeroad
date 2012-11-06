class AddObjectidToStreetNumber < ActiveRecord::Migration
  def change
    add_column :street_numbers, :objectid, :string
  end
end
