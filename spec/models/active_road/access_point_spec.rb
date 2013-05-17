require 'spec_helper'

describe ActiveRoad::AccessPoint do
  let!(:ab) { create(:physical_road, :geometry => line_string( "0 0,1 0" ), :kind => "road", :tags => {:speed => "100" }) }
  let!(:ac) { create(:physical_road, :geometry => line_string( "0 0,0 1" ), :kind => "road", :tags => {:speed => "100" }) }

  subject { ActiveRoad::Accesspoint.new( :location => point(0, 0), :physical_road => ab )  }

  describe ".from" do

    it "should return all access point with tags from the location" do
      access_points = ActiveRoad::AccessPoint.from( point(0, 0), {:speed => "10"}, "road" )
      access_points.size.should == 1
    end

    it "should return all access point from the location with tags not in physical roads" do
      access_points = ActiveRoad::AccessPoint.from( point(0, 0), {:speed => "100"} )
      access_points.size.should == 0
    end
    
  end

  describe ".to" do
  
    it "should return all access point with tags from the location" do
      access_points = ActiveRoad::AccessPoint.to( point(0, 0), {}, "road" )
      access_points.size.should == 1
    end

    it "should return all access point from the location with tags not in physical roads" do
      access_points = ActiveRoad::AccessPoint.to( point(0, 0), {:test => "AB"} )
      access_points.size.should == 0
    end
    
  end

end
