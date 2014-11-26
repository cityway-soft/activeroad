class AddAdressTagsToStreetNumber < ActiveRecord::Migration
  def change
    add_column :street_numbers, :street, :string
    add_column :street_numbers, :city, :string
    add_column :street_numbers, :state, :string
    add_column :street_numbers, :country, :string    
  end
end
