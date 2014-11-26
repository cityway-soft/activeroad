shared_examples "an OsmPbfImporter module" do 

  describe "#pedestrian?" do
    it "should return true when tag key is highway and tag value is good" do
      expect(importer.pedestrian?({"highway" => "pedestrian"})).to be_truthy
      expect(importer.pedestrian?({"highway" => "path"})).to be_truthy
    end

    it "should return false when tag key is not highway or tag value is not good" do
      expect(importer.pedestrian?({"highway" => "residential"})).to be_falsey
    end    
  end

  describe "#bike?" do
    it "should return true when tag key is highway and tag value is good" do
      expect(importer.bike?({"highway" => "cycleway"})).to be_truthy
      expect(importer.bike?({"cycleway:right" => "lane"})).to be_truthy
      expect(importer.bike?({"cycleway:left" => "lane"})).to be_truthy
      expect(importer.bike?({"cycleway" => "lane"})).to be_truthy
    end

    it "should return false when tag key is not highway or tag value is not good" do
      expect(importer.bike?({"highway" => "residential"})).to be_falsey
    end    
  end

  describe "#train?" do
    it "should return true when tag key is railway and tag value is good" do
      expect(importer.train?({"railway" => "rail"})).to be_truthy
      expect(importer.train?({"railway" => "tram"})).to be_truthy
    end

    it "should return false when tag key is not railway or tag value is not good" do
      expect(importer.train?({"highway" => "residential"})).to be_falsey
    end    
  end
  
  describe "#car?" do
    it "should return true when tag key is highway and tag value is good" do
      expect(importer.car?({"highway" => "motorway"})).to be_truthy
      expect(importer.car?({"highway" => "secondary"})).to be_truthy
    end

    it "should return false when tag key is not highway or tag value is not good" do
      expect(importer.car?({"highway" => "railway"})).to be_falsey
    end    
  end
  
  describe "#required_way?" do
    it "should return true when tag key is highway or railway" do 
      tags = {"highway" => "primary"} 
      expect(importer.required_way?(ActiveRoad::OsmPbfImporter::way_required_tags_keys, tags)).to be_truthy
    end

    it "should return false when no tag key with highway or railway" do 
      tags =  {"maxspeed" => "100", "bike" => "oneway"} 
      expect(importer.required_way?(ActiveRoad::OsmPbfImporter::way_required_tags_keys, tags)).to  be_falsey
    end
  end

  describe "#selected_tags" do
    it "should return true when " do 
      tags = {"highway" => "primary", "name" => "Rue montparnasse", "bridge" => "true", "other_tag" => "other_tag"} 
      expect(importer.selected_tags(tags, ActiveRoad::OsmPbfImporter.way_selected_tags_keys)).to eq({"name" => "Rue montparnasse" })
    end
  end

  describe "#required_relation?" do
    it "should return true when tag key is boundary" do 
      tags = {"boundary" => "administrative"} 
      expect(importer.required_relation?(tags)).to be_truthy
    end

    it "should return false when no tag key with highway or railway" do 
      tags =  {"other" => "100"} 
      expect(importer.required_relation?(tags)).to  be_falsey
    end
  end

  describe "#physical_road_conditionnal_costs" do
    let(:physical_road) { create(:physical_road) }

    it "should return conditionnal cost with pedestrian, bike and train to infinity when tag key is car" do
      expect(importer.physical_road_conditionnal_costs( ActiveRoad::OsmPbfImporter::Way.new("", [], true) )).to eq([["pedestrian", Float::MAX], ["bike", Float::MAX], ["train", Float::MAX]])
    end

    it "should return conditionnal cost with pedestrian, bike, car and train to infinity when tag key is nothing" do   
      expect(importer.physical_road_conditionnal_costs( ActiveRoad::OsmPbfImporter::Way.new("", []) )).to eq([ ["car", Float::MAX], ["pedestrian", Float::MAX], ["bike", Float::MAX], ["train", Float::MAX]])
    end
  end

  describe "#extract_relation_polygon" do
    let!(:p1) { geos_factory.point( 0, 0) }
    let!(:p2) { geos_factory.point( 1, 1) }
    let!(:p3) { geos_factory.point( 1, 0) }
    let!(:first_way_geom) {  geos_factory.line_string( [p1, p2] ) }
    let!(:second_way_geom) { geos_factory.line_string( [p2, p3] ) }
    let!(:third_way_geom) { geos_factory.line_string(  [p3, p1] ) }

    it "should return an exception if way geometries are not connected" do
      second_way_geom_not_connected = geos_factory.line_string( [p2, p2] )
      expect { importer.extract_relation_polygon([first_way_geom, second_way_geom_not_connected, third_way_geom]) }.to raise_error
    end

    it "should return polygon if way geometries are connected" do
      expect(importer.extract_relation_polygon([first_way_geom, second_way_geom, third_way_geom])).to match_array( [ geos_factory.polygon(geos_factory.line_string( [p1, p2, p3, p1] )) ] )
    end

    it "should return polygon if way geometries are connected and some of them have points in the reverse order" do
      second_way_geom_reversed = geos_factory.line_string([ p3, p2] )
      expect(importer.extract_relation_polygon([first_way_geom, second_way_geom_reversed, third_way_geom])).to match_array( [ geos_factory.polygon(geos_factory.line_string( [p1, p2, p3, p1] )) ] )
    end
      
  end

  describe "#join_ways" do
    let!(:p1) { geos_factory.point( 0, 0) }
    let!(:p2) { geos_factory.point( 1, 1) }
    let!(:p3) { geos_factory.point( 1, 0) }

    let(:way1) { geos_factory.line_string([ p1, p2] ) }
    let(:way2) { geos_factory.line_string([ p2, p3] ) }
    let(:way3) { geos_factory.line_string([ p3, p1] ) }
    let(:way2_inversed) { geos_factory.line_string([ p3, p2] ) }
    let(:way2_closed) { geos_factory.line_string([ p2, p3, p2] ) }
    
    it "should return a joined way when join 2 ways" do
      expect( importer.join_ways([way1, way2, way3]).collect(&:as_text) ).to eq(["SRID=4326;LineString (0.0 0.0, 1.0 1.0, 1.0 0.0, 0.0 0.0)"])
      expect( importer.join_ways([way1, way2_inversed, way3]).collect(&:as_text) ).to eq(["SRID=4326;LineString (0.0 0.0, 1.0 1.0, 1.0 0.0, 0.0 0.0)"])
    end

    it "should return StandardError when join one way and a closed way" do
      expect{importer.join_ways([way1, way2_closed])}.to raise_error(StandardError, "Unclosed boundaries")
    end
    
  end

  describe "#join_way" do
    let!(:p1) { geos_factory.point( 0, 0) }
    let!(:p2) { geos_factory.point( 1, 1) }
    let!(:p3) { geos_factory.point( 2, 2) }

    let(:way1) { geos_factory.line_string([ p1, p2] ) }
    let(:way2) { geos_factory.line_string([ p2, p3] ) }
    let(:way2_inversed) { geos_factory.line_string([ p3, p2] ) }
    let(:way2_closed) { geos_factory.line_string([ p2, p3, p2] ) }
    
    it "should return a joined way when join 2 ways" do
      expect(importer.join_way(way1, way2).as_text).to eq("SRID=4326;LineString (0.0 0.0, 1.0 1.0, 2.0 2.0)")
      expect(importer.join_way(way1, way2_inversed).as_text).to eq("SRID=4326;LineString (0.0 0.0, 1.0 1.0, 2.0 2.0)")
    end

    it "should return StandardError when join one way and a closed way" do
      expect{importer.join_way(way1, way2_closed)}.to raise_error(StandardError, "Trying to join a way to a closed way")
    end
    
  end

  describe ActiveRoad::OsmPbfImporter::EndpointToWayMap
  
  describe ActiveRoad::OsmPbfImporter::Way
  
  describe ActiveRoad::OsmPbfImporter::Node do
    
    let(:node) { ActiveRoad::OsmPbfImporter::Node.new("122323131", 34.2, 12.5) } 

    it "should return a node object when unmarhalling a dump of node object" do
      data = Marshal.dump(node)
      object = Marshal.load(data)
      expect(object).to be_an_instance_of(ActiveRoad::OsmPbfImporter::Node)
      expect(object.id).to eq(node.id)
      expect(object.lon).to eq(node.lon)
      expect(object.lat).to eq(node.lat)
      expect(object.ways).to eq(node.ways)
    end

    it "should return a node object with ways when we add a way" do
      node.add_way("1223344")
      data = Marshal.dump(node)
      object = Marshal.load(data)
      expect(object).to be_an_instance_of(ActiveRoad::OsmPbfImporter::Node)
      expect(object.id).to eq(node.id)
      expect(object.lon).to eq(node.lon)
      expect(object.lat).to eq(node.lat)
      expect(object.ways).to eq([ "1223344" ])
    end

  end
  
end
