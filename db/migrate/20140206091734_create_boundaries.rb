class CreateBoundaries < ActiveRecord::Migration

  def change
    create_table :boundaries do |t|
      t.string :objectid
      t.string :name
      t.integer :admin_level
      t.string :postal_code
      t.string :insee_code
      t.polygon :geometry, :srid => ActiveRoad.srid
    end
    
    add_index :boundaries, :geometry, :spatial => true
  end
     
end
