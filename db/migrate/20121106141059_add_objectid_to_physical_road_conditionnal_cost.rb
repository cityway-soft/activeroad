class AddObjectidToPhysicalRoadConditionnalCost < ActiveRecord::Migration
  def change
    add_column :physical_road_conditionnal_costs, :objectid, :string
  end
end
