require 'spec_helper'

describe ActiveRoad::RequestConditionnalCostLinker do

  let!(:physical_road) { create(:physical_road) }
  let!(:conditionnal_costs) { [ create(:physical_road_conditionnal_cost, :tags => "bike", :cost => 0.1, :physical_road => physical_road), 
                               create(:physical_road_conditionnal_cost, :tags => "pavement", :cost => 0.3, :physical_road => physical_road) ]
  }
  let(:physical_road_conditionnal_costs) { physical_road.physical_road_conditionnal_costs }

  subject { ActiveRoad::RequestConditionnalCostLinker.new(["bike", "pavement", "~asphalt"]) }
  
  describe "#authorized_constraints_intersection_with" do

    it "should return true if authorized constraints intersection" do
      subject.stub :authorized_constraints => ["bike"]
      subject.authorized_constraints_intersection_with?(["bike"]).should == true
    end
    
  end

  describe "#unauthorized_constraints_intersection_with" do

    it "should return true if unauthorized constraints intersection" do
      subject.stub :unauthorized_constraints => ["bike"]
      subject.unauthorized_constraints_intersection_with?(["bike"]).should == true
    end

  end

  describe "#linked?" do

    it "should return true if tags in conditionnal costs and tag in constraints have common tags" do
      rcc = ActiveRoad::RequestConditionnalCostLinker.new(["bike", "pavement"])
      rcc.linked?(["bike", "pavement"]).should == true
    end

    it "should return true if tags in conditionnal costs and unauthorized constraints have common tags" do
      rcc = ActiveRoad::RequestConditionnalCostLinker.new(["~asphalt"])
      physical_road_conditionnal_costs << create(:physical_road_conditionnal_cost, :tags => "asphalt", :cost => 0.1)
      rcc.linked?(["bike", "pavement", "asphalt"]).should == true
    end
    
    it "should return false if tags in conditionnal costs have common tags with authorized or unauthorized constraints" do
      rcc = ActiveRoad::RequestConditionnalCostLinker.new([])
      rcc.linked?(physical_road_conditionnal_costs).should == false
    end
    
  end

  describe "#conditionnal_costs_sum" do

    it "should return the sum for conditionnal costs" do
      subject.conditionnal_costs_sum(physical_road_conditionnal_costs).should == 0.4
    end

    it "should return infinity for conditionnal costs with an infinity value in it" do
      rcc = ActiveRoad::RequestConditionnalCostLinker.new(["bike", "pavement", "test"])
      physical_road_conditionnal_costs << create(:physical_road_conditionnal_cost, :tags => "test", :cost => Float::MAX)
      rcc.conditionnal_costs_sum(physical_road_conditionnal_costs).should == Float::INFINITY
    end
    
  end

end
