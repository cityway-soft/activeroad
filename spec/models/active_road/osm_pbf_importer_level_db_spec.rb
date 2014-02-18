require 'spec_helper'

describe ActiveRoad::OsmPbfImporterLevelDb do
  let(:pbf_file) { File.expand_path("../../../fixtures/test.osm.pbf", __FILE__) }

  subject { ActiveRoad::OsmPbfImporterLevelDb.new( pbf_file, "/tmp/osm_pbf_nodes_test_leveldb", "/tmp/osm_pbf_ways_test_leveldb" ) }

  it_behaves_like "an OsmPbfImporter module" do
    let(:importer) { subject }
  end

  describe "#backup_ways" do
    before :each do
      subject.backup_nodes
    end
    
    after :each do
      subject.close_nodes_database
      subject.delete_nodes_database
      subject.close_ways_database
      subject.delete_ways_database
    end

    it "should have import all ways in temporary ways_database" do
      subject.backup_ways
      expect(subject.ways_database.count).to eq(6)
      expect(subject.ways_database.keys).to eq(["3", "5", "6", "7", "8", "9"])
    end

    it "should have call update_node_with_way n times" do
      expect(subject).to receive(:update_node_with_way).exactly(3).times   
      subject.backup_ways
    end
                                    
  end

  
  describe "#update_node_with_ways" do
    let(:way_id) { "1" }
    let(:node_ids) { ["1", "2", "3"] }
    
    before :each do 
      subject.nodes_database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("1", 2.0, 2.0)) )
      subject.nodes_database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("2", 2.0, 2.0)) )
      subject.nodes_database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("3", 2.0, 2.0)) )
    end

    after :each do
      subject.close_nodes_database
      subject.delete_nodes_database
      subject.close_ways_database
      subject.delete_ways_database
    end

    it "should have update all nodes with way in the temporary nodes_database" do
      subject.update_node_with_way(way_id, node_ids)
      
      node1 = Marshal.load(subject.nodes_database.get("1"))
      node1.id.should ==  "1"
      node1.lon.should == 2.0
      node1.lat.should == 2.0
      node1.ways.should == ["1"]
      node1.end_of_way.should == true

      node2 = Marshal.load(subject.nodes_database.get("2"))
      node2.id.should ==  "2"
      node2.lon.should == 2.0
      node2.lat.should == 2.0
      node2.ways.should == ["1"]
      node2.end_of_way.should == false

      node3 = Marshal.load(subject.nodes_database.get("3"))
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
      subject.nodes_database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("1", 2.0, 2.0, "", ["1", "2"])) )
      subject.nodes_database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("2", 2.0, 2.0, "", ["1", "3"])) )
      subject.nodes_database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("3", 2.0, 2.0, "7,8", [])) )
    end

    after :each do
      subject.close_nodes_database
      subject.delete_nodes_database
      subject.close_ways_database
      subject.delete_ways_database
    end
    
    it "should iterate nodes to save it" do
      GeoRuby::SimpleFeatures::Point.stub :from_x_y => point
      subject.should_receive(:backup_nodes_pgsql).exactly(1).times.with([["1", point], ["2", point]], {"1" => ["1", "2"], "2" => ["1", "3"]})
      subject.should_receive(:backup_street_numbers_pgsql).exactly(1).times.with([ ["3", point, "7,8"] ], {})
      subject.iterate_nodes
    end
  end

  describe "#iterate_ways" do
    let!(:line) { line_string( "0 0,1 0" ) }
    
    before :each do 
      subject.ways_database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Way.new("1", line, ["1", "2"], true, false, false, false, "Test", "100", true, "", "", {"cycleway" => "lane"}) ) )
      subject.ways_database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Way.new("2", line, ["1", "2"], true, false, false, false, "Test", "100", true, "", "", {"toll" => "true"}) ) )
      subject.ways_database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Way.new("3", line, ["1", "2"], true, false, false, false, "Test", "100", true, "", "", {}) ) )
    end

    after :each do
      subject.close_nodes_database
      subject.delete_nodes_database
      subject.close_ways_database
      subject.delete_ways_database
    end
    
    it "should iterate ways to save it" do
      subject.should_receive(:backup_ways_pgsql).exactly(1).times.with( [["1", true, false, false, false, "Test", 111319.49079327357, line, {"cycleway"=>"lane"}], ["2", true, false, false, false, "Test", 111319.49079327357, line, {"toll"=>"true"}], ["3", true, false, false, false, "Test", 111319.49079327357, line, {}]], {"1"=>[["pedestrian", 1.7976931348623157e+308], ["bike", 1.7976931348623157e+308], ["train", 1.7976931348623157e+308]], "2"=>[["pedestrian", 1.7976931348623157e+308], ["bike", 1.7976931348623157e+308], ["train", 1.7976931348623157e+308]], "3"=>[["pedestrian", 1.7976931348623157e+308], ["bike", 1.7976931348623157e+308], ["train", 1.7976931348623157e+308]]} )
      subject.iterate_ways
    end
  end

  describe "#import" do
    it "should have import all nodes in a temporary nodes_database" do  
      subject.import
      ActiveRoad::PhysicalRoad.all.size.should == 3
      ActiveRoad::PhysicalRoad.all.collect(&:objectid).should =~ ["3", "5", "6"]
      ActiveRoad::Boundary.all.size.should == 1
      ActiveRoad::Boundary.all.collect(&:objectid).should =~ ["73464"]
      ActiveRoad::PhysicalRoadConditionnalCost.all.size.should == 9
      ActiveRoad::Junction.all.size.should == 6
      ActiveRoad::Junction.all.collect(&:objectid).should =~ ["1", "2", "5", "8", "9", "10"]
      ActiveRoad::LogicalRoad.all.size.should == 1
      ActiveRoad::LogicalRoad.all.collect(&:name).should =~ ["Rue J. Symphorien"]      
      ActiveRoad::StreetNumber.all.size.should == 2
      ActiveRoad::StreetNumber.all.collect(&:objectid).should =~ ["2646260105", "2646260106"]
    end
  end

  describe "#backup_relations_pgsql" do
    
    it "should backup boundary" do      
      subject.backup_relations_pgsql
      ActiveRoad::Boundary.all.size.should == 1
      ActiveRoad::Boundary.first.objectid.should == "73464"
      ActiveRoad::Boundary.first.geometry.should == GeoRuby::SimpleFeatures::MultiPolygon.from_polygons( [GeoRuby::SimpleFeatures::Polygon.from_points( [[ point(0.0, 0.0), point(1.0, 1.0), point(2.0, 1.0), point(0.0, 0.0)]] )])
    end

    # it "should order ways geometry" do
    #   let(:first) { line_string( "0 0,1 1" ) }
    #   let(:second) { line_string( "2 2,1 1" ) }
    #   let(:second_ordered) { line_string( "2 2,1 1" ) }
    #   let(:third) { line_string( "2 2,3 3" ) }
    #   expect(subject.order_ways_geometry( [first, second, last] )).to match_array( [first, second_ordered, third] )
    # end
    
  end

end
