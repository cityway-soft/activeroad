require 'spec_helper'

describe ActiveRoad::AccessPoint, :type => :model do
  let!(:origin) { geos_factory.point(0, 0) }
  let!(:pr1) { create(:physical_road, :geometry => "LINESTRING(0 0,1 1)" ) }
  let!(:pr2) { create(:physical_road, :geometry => "LINESTRING(0.002 0.002,1 1)" ) }
  let!(:pr3) { create(:physical_road, :geometry => "LINESTRING(2 2,3 3)" ) }
  
  #subject { ActiveRoad::Accesspoint.new( :location => point(0, 0), :physical_road => ab )  }

  describe ".from" do

    it "should return all access point with tags from the location" do
      expect( ActiveRoad::AccessPoint.from( origin ).size ).to eq(1)
    end
    
  end

  describe ".to" do
  
    it "should return all access point with tags from the location" do
      expect( ActiveRoad::AccessPoint.from( origin ).size ).to eq(1)
    end
    
  end

end
