class CreateJunctionConditionnalCosts < ActiveRoad::Migration
  def up
    create_table :junction_conditionnal_costs do |t|
      t.belongs_to :junction
      t.float :cost
      t.string :tags
    end
  end

  def down
    drop_table :junction_conditionnal_costs
  end
end
