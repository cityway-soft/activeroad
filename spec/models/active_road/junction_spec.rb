require 'spec_helper'

describe ActiveRoad::Junction do

  subject { create(:junction) }

  it "should validate objectid uniqueness" do
    other = build :junction, :objectid => subject.objectid 
    other.should_not be_valid
  end

  context "junction connected to physical roads" do
    subject { create(:junction) }

    describe "#physical_roads" do
      let(:new_road) { create(:physical_road) }
      it "should be addable" do
        subject.physical_roads << new_road
        subject.save!
      end
    end
  end
  
  
end
