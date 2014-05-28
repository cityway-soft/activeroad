require 'spec_helper'

describe ActiveRoad::Path do

  let!(:departure) { create(:junction, :geometry => "POINT(0 0)") }
  let!(:arrival) { create(:junction, :geometry => "POINT(0.5 0)") }
  let!(:physical_road) { create(:physical_road, :geometry => "LINESTRING(0 0, 1 0)") }
  subject { ActiveRoad::Path.new(:departure => departure , :arrival => arrival, :physical_road => physical_road) }

  describe ".geometry_without_cache" do
    
    it "should return line substring from a physical road" do
      expect(subject.geometry_without_cache).to eq(geos_factory.parse_wkt("LINESTRING(0 0, 0.5 0)"))
    end

    it "should return line substring reversed from a physical road if reverse" do
      subject.stub :reverse => true
      expect(subject.geometry_without_cache).to eq(geos_factory.parse_wkt("LINESTRING(0.5 0, 0 0)"))
    end   
    
  end

end
