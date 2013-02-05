require 'spec_helper'

describe ActiveRoad::PhysicalRoad do

  subject { Factory(:physical_road) }

  it "should validate objectid uniqueness" do
    other_road = Factory.build :physical_road, :objectid => subject.objectid 
    other_road.should_not be_valid
  end

  it "should be valid with a logical_road" do
    subject.logical_road = nil
    subject.should be_valid
  end

end
