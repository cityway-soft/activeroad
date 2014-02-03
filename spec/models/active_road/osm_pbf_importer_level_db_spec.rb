require 'spec_helper'
#require "../../../spec/models/osm_pbf_importer_spec.rb"

describe ActiveRoad::OsmPbfImporterLevelDb do
  let(:pbf_file) { File.expand_path("../../../fixtures/test.osm.pbf", __FILE__) }

  subject { ActiveRoad::OsmPbfImporterLevelDb.new( pbf_file, "/tmp/osm_pbf_test_leveldb" ) }

  it_behaves_like "an OsmPbfImporter module"

  describe "#update_node_with_ways" do
    let(:way) { { :id => 1, :refs => [1,2,3] } }
    
    before :each do 
      subject.database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("1", 2.0, 2.0)) )
      subject.database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("2", 2.0, 2.0)) )
      subject.database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("3", 2.0, 2.0)) )
    end

    after :each do
      subject.close_database
      subject.delete_database
    end

    it "should have update all nodes with way in the temporary database" do
      subject.update_node_with_way(way)
      
      node1 = Marshal.load(subject.database.get("1"))
      node1.id.should ==  "1"
      node1.lon.should == 2.0
      node1.lat.should == 2.0
      node1.ways.should == ["1"]
      node1.end_of_way.should == true

      node2 = Marshal.load(subject.database.get("2"))
      node2.id.should ==  "2"
      node2.lon.should == 2.0
      node2.lat.should == 2.0
      node2.ways.should == ["1"]
      node2.end_of_way.should == false

      node3 = Marshal.load(subject.database.get("3"))
      node3.id.should ==  "3"
      node3.lon.should == 2.0
      node3.lat.should == 2.0
      node3.ways.should == ["1"]
      node3.end_of_way.should == true
    end
  end

  describe "#iterate_nodes" do
    let!(:point) { GeoRuby::SimpleFeatures::Point.from_x_y( 0, 0, 4326) }

    before :each do 
      subject.database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("1", 2.0, 2.0, ["1", "2"])) )
      subject.database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("2", 2.0, 2.0, ["1", "3"])) )
    end

    after :each do
      subject.close_database
      subject.delete_database
    end
    
    it "should iterate nodes to save it" do
      GeoRuby::SimpleFeatures::Point.stub :from_x_y => point
      subject.should_receive(:backup_nodes_pgsql).exactly(1).times.with([["1", point], ["2", point]], {"1" => ["1", "2"], "2" => ["1", "3"]})
      subject.iterate_nodes
    end
  end

  describe "#import" do
    it "should have import all nodes in a temporary database" do  
      subject.import
      ActiveRoad::PhysicalRoad.all.size.should == 3
      ActiveRoad::PhysicalRoad.all.collect(&:objectid).should == ["3", "5", "6"]
      ActiveRoad::PhysicalRoadConditionnalCost.all.size.should == 9
      ActiveRoad::Junction.all.size.should == 6
      ActiveRoad::Junction.all.collect(&:objectid).should =~ ["1", "2", "5", "8", "9", "10"]
    end
  end

end
