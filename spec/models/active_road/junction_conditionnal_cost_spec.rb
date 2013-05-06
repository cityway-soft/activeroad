require 'spec_helper'

describe ActiveRoad::JunctionConditionnalCost do

  subject { create(:junction_conditionnal_cost) }

  it "should have tags" do
    subject.should respond_to(:tags)
  end

  it "should have a cost" do
    subject.should respond_to(:cost)
  end

  it "should have a junction" do
    subject.should respond_to(:junction_id)
  end

  describe "#start_physical_road" do
    let(:new_road){create(:physical_road)}
    it "should belongs to physical_road" do
      subject.update_attributes( :start_physical_road => new_road)
      subject.reload
      subject.start_physical_road_id = new_road.id
    end
  end

end
