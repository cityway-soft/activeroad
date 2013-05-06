require 'spec_helper'

describe ActiveRoad::PhysicalRoadConditionnalCost do

  subject { create(:physical_road_conditionnal_cost) }

  it "should have tags" do
    subject.should respond_to(:tags)
  end

  it "should have a cost" do
    subject.should respond_to(:cost)
  end

  it "should have a physical road" do
    subject.should respond_to(:physical_road_id)
  end

end
