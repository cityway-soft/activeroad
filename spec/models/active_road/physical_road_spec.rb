require 'spec_helper'

describe ActiveRoad::PhysicalRoad do

  subject { create(:physical_road) }

  it "should validate objectid uniqueness" do
    other_road = build :physical_road, :objectid => subject.objectid 
    other_road.should_not be_valid
  end

  it "should be valid with a logical_road" do
    subject.logical_road = nil
    subject.should be_valid
  end

  describe ".nearest_to" do 
    let(:departure) { point(0, 0) }
    let(:ab) { create(:physical_road, :geometry => line_string( "0.01 0.01,1 1" ) ) }
    let(:ac) { create(:physical_road, :geometry => line_string( "-0.02 -0.02,-1 -1" ) )  }
    let(:ad) { create(:physical_road, :geometry => line_string( "-0.011 -0.011,-1 -1" ) )  }
    
    it "should return physical roads in an area ordered from closest to farthest from a departure" do
      ActiveRoad::PhysicalRoad.nearest_to(departure).should == [ab, ad]
    end
  end

  describe "closest_to" do 
    let(:departure) { point(0, 0) }
    let(:ab) { create(:physical_road, :geometry => line_string( "0.01 0.01,1 1" ) ) }
    let(:ac) { create(:physical_road, :geometry => line_string( "-0.02 -0.02,-1 -1" ) )  }
    
    it "should return physical roads ordered from closest to farthest from a departure" do
      ActiveRoad::PhysicalRoad.closest_to(departure).should == [ab, ac]
    end
  end

  describe "with_in" do 
    let(:departure) { point(0, 0) }
    let(:ab) { create(:physical_road, :geometry => line_string( "0.01 0.01,1 1" ) ) }
    let(:ac) { create(:physical_road, :geometry => line_string( "-0.02 -0.02,-1 -1" ) )  }

    it "should return physical road in an area" do
      ActiveRoad::PhysicalRoad.with_in(departure, 100).should == [ab]
    end
  end

end
