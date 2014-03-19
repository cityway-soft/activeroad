class AddIndexToConditionnalCosts < ActiveRecord::Migration
  def change
    add_index :physical_road_conditionnal_costs, :physical_road_id
    add_index :junction_conditionnal_costs, :junction_id
  end
end
