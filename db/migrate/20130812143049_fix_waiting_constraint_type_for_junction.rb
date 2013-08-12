class FixWaitingConstraintTypeForJunction < ActiveRecord::Migration
  def up
    remove_column :junctions, :waiting_constraint
    add_column :junctions, :waiting_constraint, :float
  end

  def down
    remove_column :junctions, :waiting_constraint
    add_column :junctions, :waiting_constraint, :time
  end
end
