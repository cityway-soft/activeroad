require 'spec_helper'

describe ActiveRoad::RequestConditionnalCostLinker, :type => :model do

  let!(:physical_road) { create(:physical_road) }
  let!(:conditionnal_costs) { [ create(:physical_road_conditionnal_cost, :tags => "bike", :cost => 0.1, :physical_road => physical_road), 
                               create(:physical_road_conditionnal_cost, :tags => "pavement", :cost => 0.3, :physical_road => physical_road) ]
  }
  let(:physical_road_conditionnal_costs) { physical_road.physical_road_conditionnal_costs }

  subject { ActiveRoad::RequestConditionnalCostLinker.new(["bike", "pavement", "~asphalt"]) }
  
  describe "#authorized_constraints_intersection_with" do

    it "should return true if authorized constraints intersection" do
      allow(subject).to receive_messages :authorized_constraints => ["bike"]
      expect(subject.authorized_constraints_intersection_with?(["bike"])).to eq(true)
    end
    
  end

  describe "#unauthorized_constraints_intersection_with" do

    it "should return true if unauthorized constraints intersection" do
      allow(subject).to receive_messages :unauthorized_constraints => ["bike"]
      expect(subject.unauthorized_constraints_intersection_with?(["bike"])).to eq(true)
    end

  end

  describe "#linked?" do

    it "should return true if tags in conditionnal costs and tag in constraints have common tags" do
      rcc = ActiveRoad::RequestConditionnalCostLinker.new(["bike", "pavement"])
      expect(rcc.linked?(["bike", "pavement"])).to eq(true)
    end

    it "should return true if tags in conditionnal costs and unauthorized constraints have common tags" do
      rcc = ActiveRoad::RequestConditionnalCostLinker.new(["~asphalt"])
      physical_road_conditionnal_costs << create(:physical_road_conditionnal_cost, :tags => "asphalt", :cost => 0.1)
      expect(rcc.linked?(["bike", "pavement", "asphalt"])).to eq(true)
    end
    
    it "should return false if tags in conditionnal costs have common tags with authorized or unauthorized constraints" do
      rcc = ActiveRoad::RequestConditionnalCostLinker.new([])
      expect(rcc.linked?(physical_road_conditionnal_costs)).to eq(false)
    end
    
  end

  describe "#conditionnal_costs_sum" do

    it "should return the sum for conditionnal costs" do
      expect(subject.conditionnal_costs_sum(physical_road_conditionnal_costs)).to eq(0.4)
    end

    it "should return infinity for conditionnal costs with an infinity value in it" do
      rcc = ActiveRoad::RequestConditionnalCostLinker.new(["bike", "pavement", "test"])
      physical_road_conditionnal_costs << create(:physical_road_conditionnal_cost, :tags => "test", :cost => Float::MAX)
      expect(rcc.conditionnal_costs_sum(physical_road_conditionnal_costs)).to eq(Float::INFINITY)
    end
    
  end

end
