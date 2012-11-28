class CreatePhysicalRoadConditionnalCosts < ActiveRecord::Migration
  def up
    create_table :physical_road_conditionnal_costs do |t|
      t.belongs_to :physical_road
      t.float :cost
      t.string :tags
    end
  end

  def down
    if table_exists?(:physical_road_conditionnal_costs)
      drop_table :physical_road_conditionnal_costs
    end
  end
end
