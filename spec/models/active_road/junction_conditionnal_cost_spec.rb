require 'spec_helper'

describe ActiveRoad::JunctionConditionnalCost do

  subject { Factory(:junction_conditionnal_cost) }

  it "should have tags" do
    subject.should respond_to(:tags)
  end

  it "should have a cost" do
    subject.should respond_to(:cost)
  end

  it "should have a physical road" do
    subject.should respond_to(:junction_id)
  end
end
