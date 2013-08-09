class AddHeightAndWaitingConstraintToJunction < ActiveRecord::Migration
  def change
    add_column :junctions, :height, :float
    add_column :junctions, :waiting_constraint, :time
  end
end
