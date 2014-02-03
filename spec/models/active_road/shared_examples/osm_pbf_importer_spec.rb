require 'spec_helper'

shared_examples "an OsmPbfImporter module" do
  
  let(:pbf_file) { File.expand_path("../../../fixtures/test.osm.pbf", __FILE__) }
  let(:importer) { ActiveRoad::OsmPbfImporterLevelDb.new( pbf_file, "/tmp/osm_pbf_test" ) }

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
      importer.selected_tags(tags).should == {"highway" => "primary", "name" => "Rue montparnasse", "bridge" => "true" }
    end
  end

  describe "#physical_road_conditionnal_costs" do
    let(:physical_road) { create(:physical_road) }

    it "should return conditionnal cost with pedestrian, bike and train to infinity when tag key is car" do
      importer.physical_road_conditionnal_costs({"highway" => "primary"}).should == [["pedestrian", Float::MAX], ["bike", Float::MAX], ["train", Float::MAX]]
    end

    it "should return conditionnal cost with pedestrian, bike, car and train to infinity when tag key is nothing" do   
      importer.physical_road_conditionnal_costs({"test" => "test"}).should == [ ["car", Float::MAX], ["pedestrian", Float::MAX], ["bike", Float::MAX], ["train", Float::MAX]]
    end
  end

  describe "#way_geometry" do
    let(:way) { { :id => 1, :refs => [1,2,3] } }
    
    before :each do 
      importer.database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("1", 0.0, 0.0)) )
      importer.database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("2", 1.0, 1.0)) )
      importer.database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("3", 2.0, 2.0)) )
    end

    after :each do
      importer.close_database
      importer.delete_database
    end

    it "should update physical road geometry" do        
      importer.way_geometry(way).should ==  GeoRuby::SimpleFeatures::LineString.from_points( [point(0.0,0.0), point(1.0,1.0), point(2.0,2.0) ])
    end

  end

  describe "#save_physical_roads_and_children" do
    let(:pr1) { ActiveRoad::PhysicalRoad.new :objectid => "physicalroad::1" }
    let(:pr2) { ActiveRoad::PhysicalRoad.new :objectid => "physicalroad::2" }
    let(:physical_roads) { [ pr1, pr2 ] }
    let(:prcc) { [ "car", 0.3 ] }
    let(:physical_road_conditionnal_costs_by_objectid) { { pr1.objectid => [ prcc ] } }
    
    it "should save physical roads in postgresql database" do  
      importer.save_physical_roads_and_children(physical_roads)
      ActiveRoad::PhysicalRoad.all.size.should == 2
      ActiveRoad::PhysicalRoad.first.objectid.should == "physicalroad::1"
      ActiveRoad::PhysicalRoad.last.objectid.should == "physicalroad::2"
    end

    it "should save physical road conditionnal costs in postgresql database" do   
      importer.save_physical_roads_and_children(physical_roads, physical_road_conditionnal_costs_by_objectid)
      ActiveRoad::PhysicalRoadConditionnalCost.all.size.should == 1
      ActiveRoad::PhysicalRoadConditionnalCost.first.physical_road_id.should == ActiveRoad::PhysicalRoad.first.id
    end
  end

  describe "#backup_nodes_pgsql" do
    let!(:physical_road) { create(:physical_road, :objectid => "1") }
    let!(:point) { GeoRuby::SimpleFeatures::Point.from_x_y( 0, 0, 4326) }

    it "should save junctions in postgresql database" do         
      junctions_values = [["1", point], ["2", point]]
      junctions_ways = {"1" => ["1"], "2" => ["1"]}

      importer.backup_nodes_pgsql(junctions_values, junctions_ways)
      ActiveRoad::Junction.all.size.should == 2
      first_junction = ActiveRoad::Junction.first
      first_junction.objectid.should == "1"
      first_junction.physical_roads.should == [physical_road]

      last_junction = ActiveRoad::Junction.last
      last_junction.objectid.should == "2"
      last_junction.physical_roads.should == [physical_road]
    end
  end  

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
