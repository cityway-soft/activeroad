require 'spec_helper'

describe ActiveRoad::RgeoExt, :type => :model do

  let(:lat1) { 0 }
  let(:lon1) { 0 }
  let(:point1) { geos_factory.point(lon1, lat1)}
  
  let(:lat2) { 0 }
  let(:lon2) { 0.001 }
  let(:point2) { geos_factory.point(lon2, lat2)}

  describe ".rgeo_haversine_distance" do

    it "should find distance in different way" do
      expect( ActiveRoad::RgeoExt.rgeo_haversine_distance(point1, point2) ).to be_within(0.2).of(111)
    end
    
  end

  describe ".haversine_distance" do
    it "should find distance in different way" do
      expect( ActiveRoad::RgeoExt.haversine_distance(lat1, lon1, lat2, lon2) ).to be_within(0.2).of(111)      
    end                                      
  end
  
end
