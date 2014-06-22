require 'spec_helper'

describe ActiveRoad::PhysicalRoadConditionnalCost, :type => :model do

  subject { create(:physical_road_conditionnal_cost) }

  it "should have tags" do
    expect(subject).to respond_to(:tags)
  end

  it "should have a cost" do
    expect(subject).to respond_to(:cost)
  end

  it "should have a physical road" do
    expect(subject).to respond_to(:physical_road_id)
  end

end
