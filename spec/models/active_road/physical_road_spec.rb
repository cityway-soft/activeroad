require 'spec_helper'

describe ActiveRoad::PhysicalRoad do

  let!(:physical_roads) { [ 
                           Factory(:physical_road, :geometry => rgeometry("LINESTRING(0 0, 1 0)")),
                           Factory(:physical_road, :geometry => rgeometry("LINESTRING(1 0, 2 0)"))]}

  subject { Factory(:physical_road, :geometry => rgeometry("LINESTRING(0 0, 1 1)")) }

  it "should validate objectid uniqueness" do
    other_road = Factory.build :physical_road, :objectid => subject.objectid 
    other_road.should_not be_valid
  end

  it "should be valid with a logical_road" do
    subject.logical_road = nil
    subject.should be_valid
  end

  describe ".nearest_to" do    
    it "should return the first physical road " do
      location = rgeometry("POINT(0 0)")        
      ActiveRoad::PhysicalRoad.nearest_to(location).should == physical_roads.first
    end

    it "should return the first physical roads " do
      location = rgeometry("POINT(1 0.1)")        
      ActiveRoad::PhysicalRoad.nearest_to(location).should == physical_roads.first
    end

    it "should return the last physical roads " do
      location = rgeometry("POINT(1.01 0.1)")        
      ActiveRoad::PhysicalRoad.nearest_to(location).should == physical_roads.last
    end
  end

  describe ".closest_to" do   
    it "should return the first physical road " do
      location = rgeometry("POINT(0 0)")        
      ActiveRoad::PhysicalRoad.closest_to(location).should == [physical_roads.first]
    end

    it "should return the first physical road " do
      location = rgeometry("POINT(1 0)")        
      ActiveRoad::PhysicalRoad.closest_to(location).should == [physical_roads.first]     
    end

    it "should return the last physical roads " do
      location = rgeometry("POINT(1.01 0)")        
      ActiveRoad::PhysicalRoad.closest_to(location).should == [physical_roads.last]     
    end
  end

  describe ".with_in" do
    it "should return the first physical road " do
      location = rgeometry("POINT(0 0)")        
      ActiveRoad::PhysicalRoad.with_in(location, 100).should == [physical_roads.first]
    end

    it "should return all physical roads " do
      location = rgeometry("POINT(1 0)")        
      ActiveRoad::PhysicalRoad.with_in(location, 100).should == physical_roads     
    end

    it "should return all physical roads " do
      location = rgeometry("POINT(1.05 0)")        
      ActiveRoad::PhysicalRoad.with_in(location, 100).should == physical_roads     
    end
  end

end
