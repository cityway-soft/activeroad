require 'spec_helper'

describe ActiveRoad::Path, :type => :model do

  let!(:departure) { create(:junction, :geometry => ActiveRoad::RgeoExt.geos_factory.parse_wkt("POINT(0 0)") )  }
  let!(:arrival) { create(:junction, :geometry => ActiveRoad::RgeoExt.geos_factory.parse_wkt("POINT(0.5 0)") ) }
  let!(:physical_road) { create(:physical_road, :geometry => ActiveRoad::RgeoExt.geos_factory.parse_wkt("LINESTRING(0 0, 0.5 0,  1 0)") ) }

  subject { ActiveRoad::Path.new(:departure => departure , :arrival => arrival, :physical_road => physical_road) }
  let(:reverse_subject) {  ActiveRoad::Path.new(:departure => arrival , :arrival => departure, :physical_road => physical_road) }
  

  describe ".geometry_without_cache" do
    
    it "should return line substring from a physical road" do
      expect(subject.geometry_without_cache.as_text).to eq("SRID=4326;LineString (0.0 0.0, 0.5 0.0)")
    end

    it "should return line substring reversed from a physical road if reverse" do
      expect(reverse_subject.geometry_without_cache.as_text).to eq("SRID=4326;LineString (0.5 0.0, 0.0 0.0)")
    end   
    
  end

end
