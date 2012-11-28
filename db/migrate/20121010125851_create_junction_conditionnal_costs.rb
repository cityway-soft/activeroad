class CreateJunctionConditionnalCosts < ActiveRoad::Migration
  def up
    create_table :junction_conditionnal_costs, :force => true do |t|
      t.belongs_to :junction
      t.float :cost
      t.string :tags
    end
  end

  def down
    if table_exists?(:junction_conditionnal_costs)
      drop_table :junction_conditionnal_costs 
    end
  end
end
