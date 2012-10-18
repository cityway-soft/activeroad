class AddStartEndRefToJunctionConditionnalCost < ActiveRecord::Migration
  def change
    add_column :junction_conditionnal_costs, :start_physical_road_id, :integer
    add_column :junction_conditionnal_costs, :end_physical_road_id, :integer
  end
end
