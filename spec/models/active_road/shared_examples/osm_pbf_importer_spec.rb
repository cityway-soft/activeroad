shared_examples "an OsmPbfImporter module" do 

  describe "#pedestrian?" do
    it "should return true when tag key is highway and tag value is good" do
      importer.pedestrian?({"highway" => "pedestrian"}).should be_true
      importer.pedestrian?({"highway" => "path"}).should be_true
    end

    it "should return false when tag key is not highway or tag value is not good" do
      importer.pedestrian?({"highway" => "residential"}).should be_false
    end    
  end

  describe "#bike?" do
    it "should return true when tag key is highway and tag value is good" do
      importer.bike?({"highway" => "cycleway"}).should be_true
      importer.bike?({"cycleway:right" => "lane"}).should be_true
      importer.bike?({"cycleway:left" => "lane"}).should be_true
      importer.bike?({"cycleway" => "lane"}).should be_true
    end

    it "should return false when tag key is not highway or tag value is not good" do
      importer.bike?({"highway" => "residential"}).should be_false
    end    
  end

  describe "#train?" do
    it "should return true when tag key is railway and tag value is good" do
      importer.train?({"railway" => "rail"}).should be_true
      importer.train?({"railway" => "tram"}).should be_true
    end

    it "should return false when tag key is not railway or tag value is not good" do
      importer.train?({"highway" => "residential"}).should be_false
    end    
  end
  
  describe "#car?" do
    it "should return true when tag key is highway and tag value is good" do
      importer.car?({"highway" => "motorway"}).should be_true
      importer.car?({"highway" => "secondary"}).should be_true
    end

    it "should return false when tag key is not highway or tag value is not good" do
      importer.car?({"highway" => "railway"}).should be_false
    end    
  end
  
  describe "#required_way?" do
    it "should return true when tag key is highway or railway" do 
      tags = {"highway" => "primary"} 
      importer.required_way?(tags).should be_true
    end

    it "should return false when no tag key with highway or railway" do 
      tags =  {"maxspeed" => "100", "bike" => "oneway"} 
      importer.required_way?(tags).should  be_false
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
      importer.required_relation?(tags).should be_true
    end

    it "should return false when no tag key with highway or railway" do 
      tags =  {"other" => "100"} 
      importer.required_relation?(tags).should  be_false
    end
  end

  describe "#physical_road_conditionnal_costs" do
    let(:physical_road) { create(:physical_road) }

    it "should return conditionnal cost with pedestrian, bike and train to infinity when tag key is car" do
      importer.physical_road_conditionnal_costs( ActiveRoad::OsmPbfImporter::Way.new("", "", [], true) ).should == [["pedestrian", Float::MAX], ["bike", Float::MAX], ["train", Float::MAX]]
    end

    it "should return conditionnal cost with pedestrian, bike, car and train to infinity when tag key is nothing" do   
      importer.physical_road_conditionnal_costs( ActiveRoad::OsmPbfImporter::Way.new("", "", []) ).should == [ ["car", Float::MAX], ["pedestrian", Float::MAX], ["bike", Float::MAX], ["train", Float::MAX]]
    end
  end

  describe "#way_geometry" do
    let(:node_ids) { ["1","2","3"] }
    
    before :each do 
      importer.nodes_database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("1", 0.0, 0.0)) )
      importer.nodes_database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("2", 1.0, 1.0)) )
      importer.nodes_database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("3", 2.0, 2.0)) )
    end

    after :each do
      importer.close_nodes_database
      importer.delete_nodes_database
      subject.close_ways_database
      subject.delete_ways_database
    end

    it "should update physical road geometry" do        
      importer.way_geometry(node_ids).should ==  GeoRuby::SimpleFeatures::LineString.from_points( [point(0.0,0.0), point(1.0,1.0), point(2.0,2.0) ])
    end

  end

  describe "#backup_ways_pgsql" do
    let!(:line) { line_string( "0 0,1 0" ) }
    let(:physical_road_values) { [ [ "1", true, false, false, false, "", 1, line, nil, {} ], ["2", true, false, false, false, "", 2, line, nil, {"oneway" => "true"}] ] }
    let(:prcc) { [ "car", 0.3 ] }
    let(:physical_road_conditionnal_costs_by_objectid) { { "1" => [ prcc ] } }
    
    it "should save physical roads in postgresql database" do  
      importer.backup_ways_pgsql(physical_road_values)
      ActiveRoad::PhysicalRoad.all.size.should == 2
      ActiveRoad::PhysicalRoad.all.collect(&:objectid).should == ["1", "2"]
    end

    it "should save physical road conditionnal costs in postgresql database" do   
      importer.backup_ways_pgsql(physical_road_values, physical_road_conditionnal_costs_by_objectid)
      ActiveRoad::PhysicalRoadConditionnalCost.all.size.should == 1
      ActiveRoad::PhysicalRoadConditionnalCost.first.physical_road_id.should == ActiveRoad::PhysicalRoad.first.id
    end
  end

  describe "#backup_logical_roads_pgsql" do
    let!(:physical_road) { create(:physical_road) }
    let!(:boundary) { create(:boundary) }

    it "should not create a logical road if physical road has no boundary" do
      physical_road = create(:physical_road, :boundary_id => nil)
      subject.backup_logical_roads_pgsql
      expect(ActiveRoad::LogicalRoad.all.size).to eq(0)
    end
    
    it "should create a logical road with no name and a boundary if physical road has no name but a boundary" do
      physical_road = create(:physical_road, :boundary_id => boundary.id)
      subject.backup_logical_roads_pgsql
      expect(ActiveRoad::LogicalRoad.all.size).to eq(1)
      expect(ActiveRoad::LogicalRoad.first.attributes).to include( "boundary_id" => boundary.id )
    end


    it "should create a logical road with a name and a boundary if physical road has a name and a boundary" do
      physical_road = create(:physical_road, :boundary_id => boundary.id, :name => "Test")
      subject.backup_logical_roads_pgsql
      expect(ActiveRoad::LogicalRoad.all.size).to eq(1)
      expect(ActiveRoad::LogicalRoad.first.attributes).to include( "boundary_id" => boundary.id, "name" => "Test" )
    end

    it "should create one logical road with a name and a boundary if physical roads have same name and a boundary" do
      physical_road = create(:physical_road, :boundary_id => boundary.id, :name => "Test")
      physical_road = create(:physical_road, :boundary_id => boundary.id, :name => "Test")
      subject.backup_logical_roads_pgsql
      expect(ActiveRoad::LogicalRoad.all.size).to eq(1)
      expect(ActiveRoad::LogicalRoad.first.attributes).to include( "boundary_id" => boundary.id, "name" => "Test" )
    end
    
  end

  describe "#backup_nodes_pgsql" do
    let!(:physical_road) { create(:physical_road) }
    let!(:point) { GeoRuby::SimpleFeatures::Point.from_x_y( 0, 0, 4326) }

    it "should save junctions in postgresql nodes_database" do         
      junctions_values = [["1", point], ["2", point]]
      junctions_ways = {"1" => [ physical_road.objectid ], "2" => [ physical_road.objectid ]}

      importer.backup_nodes_pgsql(junctions_values, junctions_ways)
      ActiveRoad::Junction.all.size.should == 2
      first_junction = ActiveRoad::Junction.first
      first_junction.objectid.should == "1"
      first_junction.physical_roads.should == [physical_road]

      last_junction = ActiveRoad::Junction.last
      last_junction.objectid.should ==  "2"
      last_junction.physical_roads.should == [physical_road]
    end
  end

  describe "#backup_street_numbers_pgsql" do
    let!(:physical_road) { create(:physical_road) }
    let!(:point) { GeoRuby::SimpleFeatures::Point.from_x_y( 0, 0, 4326) }

    it "should save junctions in postgresql nodes_database" do         
      street_number_values = [["1", point, "7"], ["2", point, "7,8,9A" ]]
      street_number_ways = {}

      importer.backup_street_numbers_pgsql(street_number_values, street_number_ways)
      street_numbers = ActiveRoad::StreetNumber.all
      expect(street_numbers.size).to eq(2)
      expect(street_numbers.collect(&:objectid)).to match_array(["1", "2"])
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
      expect(importer.extract_relation_polygon([first_way_geom, second_way_geom, third_way_geom])).to eq( polygon(point(0.0,0.0), point(1.0,1.0), point(2.0,2.0)) )
    end

    it "should return polygon if way geometries are connected and some of them have points in the reverse order" do
      second_way_geom_reversed = line_string( "2 2,1 1" ) 
      expect(importer.extract_relation_polygon([first_way_geom, second_way_geom_reversed, third_way_geom])).to eq( polygon(point(0.0,0.0), point(1.0,1.0), point(2.0,2.0)) )
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
