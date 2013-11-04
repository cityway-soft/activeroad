require 'spec_helper'

describe ActiveRoad::AccessPoint do
  let!(:ab) { create(:physical_road, :geometry => line_string( "0 0,1 0" ), :minimum_width => :wide ) }

  subject { ActiveRoad::Accesspoint.new( :location => point(0, 0), :physical_road => ab )  }

  describe ".from" do

    it "should return all access point with tags from the location" do
      access_points = ActiveRoad::AccessPoint.from( point(0, 0) )
      access_points.size.should == 1
    end
    
  end

  describe ".to" do
  
    it "should return all access point with tags from the location" do
      access_points = ActiveRoad::AccessPoint.to( point(0, 0) )
      access_points.size.should == 1
    end
    
  end

end
