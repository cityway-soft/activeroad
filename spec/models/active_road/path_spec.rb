require 'spec_helper'

describe ActiveRoad::Path, :type => :model do

  let!(:departure) { create(:junction, :geometry => ActiveRoad::RgeoExt.cartesian_factory.parse_wkt("POINT(0 0)") )  }
  let!(:arrival) { create(:junction, :geometry => ActiveRoad::RgeoExt.cartesian_factory.parse_wkt("POINT(1 0)") ) }
  let!(:intermediate_arrival) { create(:junction, :geometry => ActiveRoad::RgeoExt.cartesian_factory.parse_wkt("POINT(0.5 0.0)") ) }
  let!(:departure_access_point) { create(:junction, :geometry => ActiveRoad::RgeoExt.cartesian_factory.parse_wkt("POINT(0 0)") )  }
  let!(:arrival_access_point) { create(:junction, :geometry => ActiveRoad::RgeoExt.cartesian_factory.parse_wkt("POINT(0.5 0)") ) }

  let!(:physical_road) { create(:physical_road, :geometry => ActiveRoad::RgeoExt.cartesian_factory.parse_wkt("LINESTRING(0 0, 0.5 0,  1 0)") ) }

  subject { ActiveRoad::Path.new(:departure => departure , :arrival => arrival, :physical_road => physical_road) }
  let(:reversed_path) {  ActiveRoad::Path.new(:departure => arrival , :arrival => departure, :physical_road => physical_road) }
  let(:splitted_path) {  ActiveRoad::Path.new(:departure => departure , :arrival => intermediate_arrival, :physical_road => physical_road) }
  let(:access_link_path) {  ActiveRoad::Path.new(:departure => departure_access_point, :arrival => arrival_access_point, :physical_road => physical_road) }
  
  before :each do
    physical_road.junctions << [departure, intermediate_arrival, arrival]
  end  

  describe ".geometry_without_cache" do
    
    it "should return physical road linestring when use all the physical road" do
      expect(subject.geometry_without_cache.as_text).to eq("SRID=4326;LineString (0.0 0.0, 0.5 0.0, 1.0 0.0)")
    end

    it "should return physical road linestring reversed when use all the physical in the reversed order" do
      expect(reversed_path.geometry_without_cache.as_text).to eq("SRID=4326;LineString (1.0 0.0, 0.5 0.0, 0.0 0.0)")
    end

    it "should return physical road linestring splitted when use only a part of physical road" do
      expect(splitted_path.geometry_without_cache.as_text).to eq("SRID=4326;LineString (0.0 0.0, 0.5 0.0)")
    end

    it "should return physical road linestring splitted when use only a part of physical road" do
      expect(access_link_path.geometry_without_cache.as_text).to eq("SRID=4326;LineString (0.0 0.0, 0.5 0.0)")
    end
    
  end

  describe ".paths" do
    it "should return paths from arrival - reversed path" do
      next_physical_road = create(:physical_road, :geometry => ActiveRoad::RgeoExt.cartesian_factory.parse_wkt("LINESTRING(1 0, 2 0)") )
      next_physical_road_arrival = create(:junction, :geometry => ActiveRoad::RgeoExt.cartesian_factory.parse_wkt("POINT(2 0)"))
      next_physical_road.junctions << [arrival, next_physical_road_arrival]
      expect(subject.paths.size).to eq(2)
      expect(subject.paths.last.departure).to eq(arrival)
      expect(subject.paths.last.arrival).to eq(next_physical_road_arrival)
      expect(subject.paths.last.physical_road).to eq(next_physical_road)
    end
  end

  describe ".reverse" do
    it "should return reversed path" do
      expect(subject.reverse.departure).to eq(subject.arrival)
      expect(subject.reverse.arrival).to eq(subject.departure)
      expect(subject.reverse.physical_road).to eq(subject.physical_road)
    end
  end
  
  describe ".==" do
    it "should return true if paths have same departure arrival and physical road" do
      other_path = ActiveRoad::Path.new(:departure => departure , :arrival => arrival, :physical_road => physical_road)
      expect(subject == other_path).to be_truthy      
    end

    it "should return false if paths have one difference in departure arrival or physical road" do
      other_path = ActiveRoad::Path.new(:departure => arrival , :arrival => departure, :physical_road => physical_road)
      expect(subject == other_path).to be_falsey
    end
  end

end
