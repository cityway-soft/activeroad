shared_examples "an OsmPbfImporter module" do 

  describe "#pedestrian?" do
    it "should return true when tag key is highway and tag value is good" do
      importer.pedestrian?({"highway" => "pedestrian"}).should be_truthy
      importer.pedestrian?({"highway" => "path"}).should be_truthy
    end

    it "should return false when tag key is not highway or tag value is not good" do
      importer.pedestrian?({"highway" => "residential"}).should be_falsey
    end    
  end

  describe "#bike?" do
    it "should return true when tag key is highway and tag value is good" do
      importer.bike?({"highway" => "cycleway"}).should be_truthy
      importer.bike?({"cycleway:right" => "lane"}).should be_truthy
      importer.bike?({"cycleway:left" => "lane"}).should be_truthy
      importer.bike?({"cycleway" => "lane"}).should be_truthy
    end

    it "should return false when tag key is not highway or tag value is not good" do
      importer.bike?({"highway" => "residential"}).should be_falsey
    end    
  end

  describe "#train?" do
    it "should return true when tag key is railway and tag value is good" do
      importer.train?({"railway" => "rail"}).should be_truthy
      importer.train?({"railway" => "tram"}).should be_truthy
    end

    it "should return false when tag key is not railway or tag value is not good" do
      importer.train?({"highway" => "residential"}).should be_falsey
    end    
  end
  
  describe "#car?" do
    it "should return true when tag key is highway and tag value is good" do
      importer.car?({"highway" => "motorway"}).should be_truthy
      importer.car?({"highway" => "secondary"}).should be_truthy
    end

    it "should return false when tag key is not highway or tag value is not good" do
      importer.car?({"highway" => "railway"}).should be_falsey
    end    
  end
  
  describe "#required_way?" do
    it "should return true when tag key is highway or railway" do 
      tags = {"highway" => "primary"} 
      importer.required_way?(tags).should be_truthy
    end

    it "should return false when no tag key with highway or railway" do 
      tags =  {"maxspeed" => "100", "bike" => "oneway"} 
      importer.required_way?(tags).should  be_falsey
    end
  end

  describe "#selected_tags" do
    it "should return true when " do 
      tags = {"highway" => "primary", "name" => "Rue montparnasse", "bridge" => "true", "other_tag" => "other_tag"} 
      importer.selected_tags(tags, ActiveRoad::OsmPbfImporter.way_selected_tags_keys).should == {"name" => "Rue montparnasse" }
    end
  end

  describe "#required_relation?" do
    it "should return true when tag key is boundary" do 
      tags = {"boundary" => "administrative"} 
      importer.required_relation?(tags).should be_truthy
    end

    it "should return false when no tag key with highway or railway" do 
      tags =  {"other" => "100"} 
      importer.required_relation?(tags).should  be_falsey
    end
  end

  describe "#physical_road_conditionnal_costs" do
    let(:physical_road) { create(:physical_road) }

    it "should return conditionnal cost with pedestrian, bike and train to infinity when tag key is car" do
      importer.physical_road_conditionnal_costs( ActiveRoad::OsmPbfImporter::Way.new("", [], true) ).should == [["pedestrian", Float::MAX], ["bike", Float::MAX], ["train", Float::MAX]]
    end

    it "should return conditionnal cost with pedestrian, bike, car and train to infinity when tag key is nothing" do   
      importer.physical_road_conditionnal_costs( ActiveRoad::OsmPbfImporter::Way.new("", []) ).should == [ ["car", Float::MAX], ["pedestrian", Float::MAX], ["bike", Float::MAX], ["train", Float::MAX]]
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
      object.should be_an_instance_of(ActiveRoad::OsmPbfImporter::Node)
      object.id.should == node.id
      object.lon.should == node.lon
      object.lat.should == node.lat
      object.ways.should == node.ways
    end

    it "should return a node object with ways when we add a way" do
      node.add_way("1223344")
      data = Marshal.dump(node)
      object = Marshal.load(data)
      object.should be_an_instance_of(ActiveRoad::OsmPbfImporter::Node)
      object.id.should == node.id
      object.lon.should == node.lon
      object.lat.should == node.lat
      object.ways.should == [ "1223344" ]
    end

  end
  
end
