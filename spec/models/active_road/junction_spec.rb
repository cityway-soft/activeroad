require 'spec_helper'

describe ActiveRoad::Junction do

  subject { Factory(:junction) }

  it "should validate objectid uniqueness" do
    other = Factory.build :junction, :objectid => subject.objectid 
    other.should_not be_valid
  end

  context "junction connected to physical roads" do
    subject { Factory(:junction_linked) }

    describe "#physical_roads" do
      let(:new_road){Factory(:physical_road)}
      it "should be addable" do
        subject.physical_roads << new_road
        subject.save!
      end
    end
  end
  
  
end
