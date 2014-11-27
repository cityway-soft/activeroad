require 'spec_helper'

describe ActiveRoad::OsmPbfImporterLevelDb, :type => :model do
  let(:pbf_file) { File.expand_path("../../../fixtures/test.osm.pbf", __FILE__) }
  let!(:subject_without_data) { ActiveRoad::OsmPbfImporterLevelDb.new( "", true, false, "/tmp/test/without_data/" ) }
  let!(:subject_without_split) { ActiveRoad::OsmPbfImporterLevelDb.new( pbf_file, false, false, "/tmp/test/without_split/" ) }
  
  subject { ActiveRoad::OsmPbfImporterLevelDb.new( pbf_file, true, false, "/tmp/test/basic/" ) }  

  it_behaves_like "an OsmPbfImporter module" do
    let(:importer) { subject }
  end

  describe "#import" do
    
    it "should import all datas when split" do  
      subject.import
      expect(ActiveRoad::Junction.all.size).to eq(6)
      expect(ActiveRoad::Junction.all.collect(&:objectid)).to match_array(["1", "2", "5", "8", "9", "10"])
      expect(ActiveRoad::StreetNumber.all.size).to eq(4)
      expect(ActiveRoad::StreetNumber.all.collect(&:objectid)).to match_array(["2646260105", "2646260106", "76809952", "2"])
      expect(ActiveRoad::PhysicalRoad.all.size).to eq(8)
      expect(ActiveRoad::PhysicalRoad.all.collect(&:objectid)).to match_array(["3-0", "3-1", "5-0", "5-1", "5-2", "6-0", "6-1", "6-2"])
      expect(ActiveRoad::PhysicalRoadConditionnalCost.all.size).to eq(24)
      expect(ActiveRoad::JunctionsPhysicalRoad.all.size).to eq(16)
      expect(ActiveRoad::Boundary.all.size).to eq(1)
      expect(ActiveRoad::Boundary.all.collect(&:objectid)).to match_array(["73464"])     
      expect(ActiveRoad::LogicalRoad.all.size).to eq(1)  
      expect(ActiveRoad::LogicalRoad.all.collect(&:name)).to match_array(["Rue J. Symphorien"])
    end

    it "should import only ways, nodes and street number when no split" do  
      subject_without_split.import
      expect(ActiveRoad::Junction.all.size).to eq(6)
      expect(ActiveRoad::Junction.all.collect(&:objectid)).to match_array(["1", "2", "5", "8", "9", "10"])
      expect(ActiveRoad::StreetNumber.all.size).to eq(4)
      expect(ActiveRoad::StreetNumber.all.collect(&:objectid)).to match_array(["2646260105", "2646260106", "76809952", "2"])
      expect(ActiveRoad::PhysicalRoad.all.size).to eq(3)
      expect(ActiveRoad::PhysicalRoad.all.collect(&:objectid)).to match_array(["3-0", "5-0", "6-0"])
      expect(ActiveRoad::PhysicalRoadConditionnalCost.all.size).to eq(9)
      expect(ActiveRoad::JunctionsPhysicalRoad.all.size).to eq(11)
      expect(ActiveRoad::Boundary.all.size).to eq(1)
      expect(ActiveRoad::LogicalRoad.all.size).to eq(1)
      expect(ActiveRoad::LogicalRoad.all.collect(&:name)).to match_array(["Rue J. Symphorien"])
    end
  end

  describe "#pedestrian?" do
    it "should return true when tag key is highway and tag value is good" do
      expect(subject.pedestrian?({"highway" => "pedestrian"})).to be_truthy
      expect(subject.pedestrian?({"highway" => "path"})).to be_truthy
    end

    it "should return false when tag key is not highway or tag value is not good" do
      expect(subject.pedestrian?({"highway" => "residential"})).to be_falsey
    end    
  end

  describe "#bike?" do
    it "should return true when tag key is highway and tag value is good" do
      expect(subject.bike?({"highway" => "cycleway"})).to be_truthy
      expect(subject.bike?({"cycleway:right" => "lane"})).to be_truthy
      expect(subject.bike?({"cycleway:left" => "lane"})).to be_truthy
      expect(subject.bike?({"cycleway" => "lane"})).to be_truthy
    end

    it "should return false when tag key is not highway or tag value is not good" do
      expect(subject.bike?({"highway" => "residential"})).to be_falsey
    end    
  end

  describe "#train?" do
    it "should return true when tag key is railway and tag value is good" do
      expect(subject.train?({"railway" => "rail"})).to be_truthy
      expect(subject.train?({"railway" => "tram"})).to be_truthy
    end

    it "should return false when tag key is not railway or tag value is not good" do
      expect(subject.train?({"highway" => "residential"})).to be_falsey
    end    
  end
  
  describe "#car?" do
    it "should return true when tag key is highway and tag value is good" do
      expect(subject.car?({"highway" => "motorway"})).to be_truthy
      expect(subject.car?({"highway" => "secondary"})).to be_truthy
    end

    it "should return false when tag key is not highway or tag value is not good" do
      expect(subject.car?({"highway" => "railway"})).to be_falsey
    end    
  end

  describe "#required_way?" do
    it "should return true when tag key is highway or railway" do 
      tags = {"highway" => "primary"} 
      expect(subject.required_way?(ActiveRoad::OsmPbfImporter::way_required_tags_keys, tags)).to be_truthy
    end

    it "should return false when no tag key with highway or railway" do 
      tags =  {"maxspeed" => "100", "bike" => "oneway"} 
      expect(subject.required_way?(ActiveRoad::OsmPbfImporter::way_required_tags_keys, tags)).to  be_falsey
    end
  end

  describe "#required_relation?" do
    it "should return true when tag key is boundary" do 
      tags = {"boundary" => "administrative"} 
      expect(subject.required_relation?(tags)).to be_truthy
    end

    it "should return false when no tag key with highway or railway" do 
      tags =  {"other" => "100"} 
      expect(subject.required_relation?(tags)).to  be_falsey
    end
  end

  describe "#selected_tags" do
    it "should return true when " do 
      tags = {"highway" => "primary", "name" => "Rue montparnasse", "bridge" => "true", "other_tag" => "other_tag"} 
      expect(subject.selected_tags(tags, ActiveRoad::OsmPbfImporter.way_selected_tags_keys)).to eq({"name" => "Rue montparnasse" })
    end
  end
  
  describe "#backup_nodes" do

    it "should test backup_nodes"
    
  end
    
  describe "#update_nodes_with_way" do
    before :each do
      subject.backup_nodes
    end
    
    after :each do
      subject.close_nodes_database
    end

    it "should have call update_node_with_way n times" #do
      #expect(subject).to receive(:update_node_with_way).exactly(3).times   
      #subject.update_nodes_with_way
    #end
                                    
  end

  describe "#backup_ways" do
    before :each do
      subject.nodes_database
      subject.ways_database
      
      subject.backup_nodes
      subject.update_nodes_with_way
    end
    
    after :each do
      subject.close_nodes_database
      subject.delete_nodes_database
      subject.close_ways_database
      subject.delete_ways_database
    end

    it "should have import all ways in temporary ways_database" do
      subject.backup_ways
      expect(subject.ways_database.count).to eq(13)
      expect(subject.ways_database.keys).to eq(["2", "3-0", "3-1", "5-0", "5-1", "5-2", "6-0", "6-1", "6-2", "7","76809952", "8", "9"])
    end
                                    
  end
  
  describe ActiveRoad::OsmPbfImporterLevelDb::Way
  
  describe ActiveRoad::OsmPbfImporterLevelDb::Node do
    
    let(:node) { ActiveRoad::OsmPbfImporterLevelDb::Node.new("122323131", 34.2, 12.5) } 

    it "should return a node object when unmarhalling a dump of node object" do
      data = Marshal.dump(node)
      object = Marshal.load(data)
      expect(object).to be_an_instance_of(ActiveRoad::OsmPbfImporterLevelDb::Node)
      expect(object.id).to eq(node.id)
      expect(object.lon).to eq(node.lon)
      expect(object.lat).to eq(node.lat)
      expect(object.ways).to eq(node.ways)
    end

    it "should return a node object with ways when we add a way" do
      node.add_way("1223344")
      data = Marshal.dump(node)
      object = Marshal.load(data)
      expect(object).to be_an_instance_of(ActiveRoad::OsmPbfImporterLevelDb::Node)
      expect(object.id).to eq(node.id)
      expect(object.lon).to eq(node.lon)
      expect(object.lat).to eq(node.lat)
      expect(object.ways).to eq([ "1223344" ])
    end

  end

  describe "#way_geometry" do
    let(:nodes) { [double("node1", :id => "1", :lon => 0.0, :lat => 0.0), double("node2", :id => "2", :lon => 1.0, :lat => 1.0), double("node3", :id => "3", :lon => 2.0, :lat => 2.0)] }
    
    it "should update physical road geometry" do        
      expect(subject.way_geometry(nodes)).to eq(geos_factory.parse_wkt( "LINESTRING(0.0 0.0, 1.0 1.0,2.0 2.0)"))
    end

  end
  
  describe "#split_way_with_nodes" do
    let!(:simple_way) { ActiveRoad::OsmPbfImporterLevelDb::Way.new("1", ["1", "2", "3"], false, false, true, true, "SimpleWay" ) }
    let(:complex_way) { ActiveRoad::OsmPbfImporterLevelDb::Way.new("2", ["4", "5", "6", "7", "8"], false, false, true, true, "ComplexWay" ) }
    let(:complex_way_boundary) { ActiveRoad::OsmPbfImporterLevelDb::Way.new( "2", ["4", "6", "8"], false, false, true, true, "ComplexWayBoundary" ) }

    before :each do
      # Nodes for simple way
      subject_without_data.nodes_database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("1", -1.0, 1.0, "", [simple_way.id], true)) )
      subject_without_data.nodes_database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("2", 0.0, 1.0, "", [simple_way.id, "2"])) )
      subject_without_data.nodes_database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("3", 1.0, 1.0, "", [simple_way.id], true)) )

      #Nodes for complex way
      subject_without_data.nodes_database.put("4", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("4", -1.0, 1.0, "", [complex_way.id], true)) )
      subject_without_data.nodes_database.put("5", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("5", 0.0, 1.0, "", [complex_way.id] )) )
      subject_without_data.nodes_database.put("6", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("6", 1.0, 1.0, "", [complex_way.id, "3"] )) )
      subject_without_data.nodes_database.put("7", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("7", 1.0, 2.0, "", [complex_way.id] )) )
      subject_without_data.nodes_database.put("8", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("8", 1.0, 3.0, "", [complex_way.id], true)) )
    end
    
    after :each do
      subject_without_data.nodes_database.delete("1")
      subject_without_data.nodes_database.delete("2")
      subject_without_data.nodes_database.delete("3")
      subject_without_data.nodes_database.delete("4")
      subject_without_data.nodes_database.delete("5")
      subject_without_data.nodes_database.delete("6")
      subject_without_data.nodes_database.delete("7")
      subject_without_data.nodes_database.delete("8")
      subject_without_data.close_nodes_database
    end

    it "should return ways splitted" do
      ways_splitted = subject_without_data.split_way_with_nodes(simple_way)
      expect(ways_splitted.size).to eq(2)
      expect(ways_splitted.first.instance_values).to include(
                                                             "id" => "1-0",
                                                             "car"=> false,
                                                             "bike" => false,
                                                             "train" => true,
                                                             "pedestrian" => true,
                                                             "name" => "SimpleWay",
                                                             "boundary" => "",
                                                             "options" => {"first_node_id"=>"1", "last_node_id"=>"2"},
                                                             "nodes" => ["1", "2"] )
      expect(ways_splitted.last.instance_values).to include( "id" => "1-1",
                                                             "car"=> false,
                                                             "bike" => false,
                                                             "train" => true,
                                                             "pedestrian" => true,
                                                             "name" => "SimpleWay",
                                                             "boundary" => "",
                                                             "options" => {"first_node_id"=>"2", "last_node_id"=>"3"},
                                                             "nodes" => ["2", "3"] )
    end

    it "should return ways not splitted" do
      allow(subject_without_data).to receive_messages :ways_split => false
      ways_splitted = subject_without_data.split_way_with_nodes(simple_way)
      expect(ways_splitted.size).to eq(1)
      expect(ways_splitted.first.instance_values).to include(
                                                             "id" => "1-0",
                                                             "car"=> false,
                                                             "bike" => false,
                                                             "train" => true,
                                                             "pedestrian" => true,
                                                             "name" => "SimpleWay",
                                                             "boundary" => "",
                                                             "options" => { "first_node_id"=>"1", "last_node_id"=>"3" },
                                                             "nodes" => ["1", "2", "3"]              )
    end
    
  end  

end
