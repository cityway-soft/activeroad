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

  describe ".locate_point" do
    let!(:p1) { geos_factory.point(0, 0) }    
    let!(:p2) { geos_factory.point(0.5, 2) }
    let!(:p3) { geos_factory.point(1, 0) }    
    let!(:ab) { create(:physical_road, :geometry => geos_factory.line_string( [p1, p3] ) ) }    
    
    it "should locate point in fraction with a projection on a linestring" do
      ab.locate_point(p2).should == 0.5
    end
  end

  describe ".interpolate_point" do
    let!(:p1) { geos_factory.point(0, 0) }    
    let!(:p2) { geos_factory.point(0.5, 0) }
    let!(:p3) { geos_factory.point(1, 0) }
    let!(:ab) { create(:physical_road, :geometry => geos_factory.line_string( [p1, p3] ) ) }    
    
    it "should return point from a fraction on a linestring" do
      ab.interpolate_point(0.5).should == p2
    end
  end
  
  describe ".nearest_to" do
    let(:departure) { geos_factory.point(0, 0) }
    let!(:ab) { create(:physical_road, :geometry => "LINESTRING(0.0001 0.0001,1 1)" ) }
    let!(:ac) { create(:physical_road, :geometry => "LINESTRING(-0.0001 -0.0001,-1 -1)" ) }
    let!(:ad) { create(:physical_road, :geometry => "LINESTRING(-0.001 -0.001,-1 -1)" ) }
    
    it "should return physical roads in an area ordered from closest to farthest from a departure" do
      ActiveRoad::PhysicalRoad.nearest_to(departure).should == [ab] #[ab, ac]
    end
  end

end
