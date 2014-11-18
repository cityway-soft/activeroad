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
    let!(:first_way_geom) { line_string( "0 0,1 1" ) }
    let!(:second_way_geom) { line_string( "1 1,2 2" ) }
    let!(:third_way_geom) { line_string( "2 2,0 0" ) }

    it "should return an exception if way geometries are not connected" do
      second_way_geom_not_connected = line_string( "1 1,3 3" )
      expect { importer.extract_relation_polygon([first_way_geom, second_way_geom_not_connected, third_way_geom]) }.to raise_error
    end

    it "should return polygon if way geometries are connected" do
      expect(importer.extract_relation_polygon([first_way_geom, second_way_geom, third_way_geom])).to match_array( [ polygon(point(0.0,0.0), point(1.0,1.0), point(2.0,2.0)) ] )
    end

    it "should return polygon if way geometries are connected and some of them have points in the reverse order" do
      second_way_geom_reversed = line_string( "2 2,1 1" ) 
      expect(importer.extract_relation_polygon([first_way_geom, second_way_geom_reversed, third_way_geom])).to match_array( [ polygon(point(0.0,0.0), point(1.0,1.0), point(2.0,2.0)) ] )
    end
      
  end

  describe "#join_ways"

  describe "#join_way"

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
