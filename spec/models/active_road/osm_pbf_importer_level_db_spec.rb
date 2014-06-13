require 'spec_helper'

describe ActiveRoad::OsmPbfImporterLevelDb do
  let(:pbf_file) { File.expand_path("../../../fixtures/test.osm.pbf", __FILE__) }
  let!(:subject_without_data) { ActiveRoad::OsmPbfImporterLevelDb.new( "", true, "/tmp/osm_pbf_nodes_test_without_data_leveldb", "/tmp/osm_pbf_ways_test_without_data_leveldb" ) }
  
  subject { ActiveRoad::OsmPbfImporterLevelDb.new( pbf_file, true, "/tmp/osm_pbf_nodes_test_leveldb", "/tmp/osm_pbf_ways_test_leveldb" ) }  

  it_behaves_like "an OsmPbfImporter module" do
    let(:importer) { subject }
  end
  
  describe "#update_nodes_with_way" do
    before :each do
      subject.backup_nodes
    end
    
    after :each do
      subject.close_nodes_database
    end

    it "should have call update_node_with_way n times" do
      expect(subject).to receive(:update_node_with_way).exactly(3).times   
      subject.update_nodes_with_way
    end
                                    
  end

  describe "#backup_ways" do
    before :each do
      subject.backup_nodes
    end
    
    after :each do
      subject.close_nodes_database
      subject.close_ways_database
    end

    it "should have import all ways in temporary ways_database" do
      subject.backup_ways
      expect(subject.ways_database.count).to eq(6)
      expect(subject.ways_database.keys).to eq(["3", "5", "6", "7", "8", "9"])
    end
                                    
  end
  
  describe "#update_node_with_way" do
    let(:way_id) { "1" }
    let(:node_ids) { ["1", "2", "3"] }
    
    before :each do 
      subject_without_data.nodes_database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("1", 2.0, 2.0)) )
      subject_without_data.nodes_database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("2", 2.0, 2.0)) )
      subject_without_data.nodes_database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("3", 2.0, 2.0)) )
    end

    after :each do
      subject_without_data.nodes_database.delete("1")
      subject_without_data.nodes_database.delete("2")
      subject_without_data.nodes_database.delete("3")

      subject_without_data.close_nodes_database
    end

    it "should have update all nodes with way in the temporary nodes_database" do
      subject_without_data.update_node_with_way(way_id, node_ids)
      
      node1 = Marshal.load(subject_without_data.nodes_database.get("1"))
      node1.id.should ==  "1"
      node1.lon.should == 2.0
      node1.lat.should == 2.0
      node1.ways.should == ["1"]
      node1.end_of_way.should == true

      node2 = Marshal.load(subject_without_data.nodes_database.get("2"))
      node2.id.should ==  "2"
      node2.lon.should == 2.0
      node2.lat.should == 2.0
      node2.ways.should == ["1"]
      node2.end_of_way.should == false

      node3 = Marshal.load(subject_without_data.nodes_database.get("3"))
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
      subject_without_data.nodes_database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("1", 2.0, 2.0, "", ["1", "2"], false, {"junction" => "roundabout"})) )
      subject_without_data.nodes_database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("2", 2.0, 2.0, "", ["1", "3"])) )
      subject_without_data.nodes_database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("3", 2.0, 2.0, "7,8", [], false, {"addr:street" => "Rue de Noaille"})) )
    end

    after :each do
      subject_without_data.nodes_database.delete("1")
      subject_without_data.nodes_database.delete("2")
      subject_without_data.nodes_database.delete("3")

      subject_without_data.close_nodes_database
    end
    
    it "should iterate nodes to save it" do
      # GeoRuby::SimpleFeatures::Point.stub :from_x_y => point
      # subject_without_data.should_receive(:backup_nodes_pgsql).exactly(1).times.with([["1", point, {"junction" => "roundabout"}], ["2", point, {}] ])
      # subject_without_data.should_receive(:backup_street_numbers_pgsql).exactly(1).times.with([ ["3", point, "7,8", {"addr:street" => "Rue de Noaille"}] ])
      subject_without_data.iterate_nodes
      expect(ActiveRoad::Junction.all.collect(&:objectid)).to match_array(["1", "2"])
    end
  end

  describe "#iterate_ways" do
    let!(:line) { line_string( "0 0,2 2" ) }
    let!(:line2) { line_string( "2 2,3 3" ) }
    let!(:boundary) { create(:boundary, :geometry => multi_polygon( [ polygon( point(0,0), point(2,0), point(2,2), point(0,2) ) ] ) ) }
    
    before :each do
      subject_without_data.nodes_database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("1", 0.0, 0.0, "", ["1", "2"])) )
      subject_without_data.nodes_database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("2", 2.0, 2.0, "", ["1", "3"])) )
      subject_without_data.nodes_database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("3", 3.0, 3.0, "", ["1", "3"])) )
      subject_without_data.ways_database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Way.new("1", ["1", "2", "3"], true, false, false, false, "Test", "100", true, "", "", {"cycleway" => "lane"}) ) )
      subject_without_data.ways_database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Way.new("2", ["1", "2"], true, false, false, false, "Test", "100", true, "", "", {"toll" => "true"}) ) )
      subject_without_data.ways_database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Way.new("3", ["1", "2"], true, false, false, false, "Test", "100", true, "", "", {}) ) )
    end

    after :each do
      subject_without_data.nodes_database.delete("1")
      subject_without_data.nodes_database.delete("2")
      subject_without_data.nodes_database.delete("3")

      subject_without_data.ways_database.delete("1")
      subject_without_data.ways_database.delete("2")
      subject_without_data.ways_database.delete("3")

      subject_without_data.close_nodes_database
      subject_without_data.close_ways_database
    end
    
    it "should iterate ways to save it" do     
      subject_without_data.iterate_ways
      expect(ActiveRoad::PhysicalRoad.all.collect(&:objectid)).to match_array(["1-0", "1-1", "2-0", "3-0"]
)
      expect(ActiveRoad::JunctionsPhysicalRoad.all.size).to eq(8)
      expect(ActiveRoad::PhysicalRoadConditionnalCost.all.size).to eq(12)
    end
  end

  describe "#way_geometry" do
    let(:nodes) { [double("node1", :id => "1", :lon => 0.0, :lat => 0.0), double("node2", :id => "2", :lon => 1.0, :lat => 1.0), double("node3", :id => "3", :lon => 2.0, :lat => 2.0)] }
    
    it "should update physical road geometry" do        
      subject.way_geometry(nodes).should ==  GeoRuby::SimpleFeatures::LineString.from_points( [point(0.0,0.0), point(1.0,1.0), point(2.0,2.0) ])
    end

  end
  
  describe "#split_way_with_nodes" do
    let!(:simple_way) { double("way", :id => "1", :car => false, :bike => false, :train => true, :pedestrian => true, :name => "", :nodes => ["1", "2", "3"], :geometry => nil , :options => {} ) }
    let(:complex_way) { double("way", :id => "2", :car => false, :bike => false, :train => true, :pedestrian => true, :name => "", :nodes => ["4", "5", "6", "7", "8"], :geometry => nil , :options => {} ) }
    let(:complex_way_boundary) { double("way", :id => "2", :car => false, :bike => false, :train => true, :pedestrian => true, :name => "", :nodes => ["4", "6", "8"], :geometry => nil , :options => {} ) }

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
      expect(subject_without_data.split_way_with_nodes(simple_way)).to include( { "1-0" => {:objectid=>"1-0", :car=>false, :bike=>false, :train=>true, :pedestrian=>true, :name=>"", :geometry=>line_string( "-1 1,0 1").as_hex_ewkb, :boundary_id=>nil, :tags=>{"first_node_id"=>"1", "last_node_id"=>"2"}, :conditionnal_costs=>[["car", Float::MAX], ["bike", Float::MAX]], :junctions=>["1", "2"]},
                                                                                      "1-1" => {:objectid=>"1-1", :car=>false, :bike=>false, :train=>true, :pedestrian=>true, :name=>"", :geometry=>line_string( "0 1,1 1").as_hex_ewkb, :boundary_id=>nil, :tags=>{"first_node_id"=>"2", "last_node_id"=>"3"}, :conditionnal_costs=>[["car", Float::MAX], ["bike", Float::MAX]], :junctions=>["2", "3"]} } )
    end

    it "should return ways not splitted" do
      subject_without_data.stub :split_ways => false
      expect(subject_without_data.split_way_with_nodes(simple_way)).to include( { "1-0" => {:objectid=>"1-0", :car=>false, :bike=>false, :train=>true, :pedestrian=>true, :name=>"", :geometry=>line_string( "-1 1,0 1,1 1").as_hex_ewkb, :boundary_id=>nil, :tags=>{"first_node_id"=>"1", "last_node_id"=>"3"}, :conditionnal_costs=>[["car", Float::MAX], ["bike", Float::MAX]], :junctions=>["1", "2", "3"]} } )
    end
    
  end

  describe "#split_way_with_boundaries" do        
    let!(:boundary) { create(:boundary, :geometry => multi_polygon( [ polygon( point(0,0), point(2,0), point(2,2), point(0,2), point(0,0) ) ] ) ) }
    let!(:boundary2) { create(:boundary, :geometry => multi_polygon( [ polygon( point(0,2), point(2,2), point(2,4), point(0,4) ) ] ) ) }
    
    it "should split way in three parts" do
      physical_road = create(:physical_road, :geometry => line_string("-1.0 1.0, 1.0 1.0, 1.0 2.0, 1.0 3.0"), :boundary_id => nil, :tags => {"bridge" => "true", "first_node_id" => "1", "last_node_id" => "2"})
      departure = create(:junction, :geometry => point(-1.0, 1.0))
      arrival = create(:junction, :geometry => point(1.0, 3.0))
      physical_road.junctions << [departure, arrival]
      
      subject_without_data.split_way_with_boundaries
      expect(ActiveRoad::PhysicalRoad.all.size).to eq(3)
      expect(ActiveRoad::PhysicalRoad.all.collect(&:objectid)).to match_array(["#{physical_road.objectid}-0", "#{physical_road.objectid}-1", "#{physical_road.objectid}-2"])

      expect(ActiveRoad::Junction.all.size).to eq(4)
      expect(ActiveRoad::Junction.all.collect(&:objectid)).to match_array(["#{departure.objectid}", "#{departure.objectid}-#{arrival.objectid}-0", "#{departure.objectid}-#{arrival.objectid}-1", "#{arrival.objectid}"])

      expect(ActiveRoad::PhysicalRoad.all.collect(&:boundary_id)).to match_array([nil, boundary.id, boundary2.id])
      expect(ActiveRoad::PhysicalRoad.all.collect(&:tags)).to match_array( [{"bridge"=>"true", "last_node_id"=>"#{departure.objectid}-#{arrival.objectid}-0", "first_node_id"=>"#{departure.objectid}"}, {"bridge"=>"true", "last_node_id"=>"#{departure.objectid}-#{arrival.objectid}-1", "first_node_id"=>"#{departure.objectid}-#{arrival.objectid}-0"}, {"bridge"=>"true", "last_node_id"=>"#{arrival.objectid}", "first_node_id"=>"#{departure.objectid}-#{arrival.objectid}-1"}] )
      
    end

    # Split intersection between segment on perimeter and segment in boundary
    it "should treat geometry differences with multi linestring" do
      physical_road = create(:physical_road, :geometry => line_string("-1.0 1.0, 1.0 1.0, 1.0 2.0, -1.0 2.0"), :boundary_id => nil)
      departure = create(:junction, :geometry => point(-1.0, 1.0))
      arrival = create(:junction, :geometry => point(-1.0, 2.0))
      physical_road.junctions << [departure, arrival]
      
      subject_without_data.split_way_with_boundaries
      expect(ActiveRoad::PhysicalRoad.all.size).to eq(4)
    end

    it "should update boundary_id" do
      physical_road = create(:physical_road, :geometry => line_string("0.0 1.0,1.0 1.0"), :boundary_id => nil)
      departure = create(:junction, :geometry => point(0.0, 1.0))
      arrival = create(:junction, :geometry => point(1.0, 1.0))
      physical_road.junctions << [departure, arrival]
      
      subject_without_data.split_way_with_boundaries
      expect(ActiveRoad::PhysicalRoad.all.size).to eq(1)
      expect(ActiveRoad::PhysicalRoad.all.collect(&:boundary_id)).to match_array([boundary.id])      
    end

    #     it "should return ways splitted with boundary" do
    #   boundary = create(:boundary, :geometry => multi_polygon( [ polygon( point(0,0), point(2,0), point(2,2), point(0,2) ) ] ) )
    #   boundary2 = create(:boundary, :geometry => multi_polygon( [ polygon( point(0,2), point(2,2), point(2,4), point(0,4) ) ] ) )        
    #   expect(subject_without_data.split_way_with_nodes(complex_way_boundary)).to match_array( [{:objectid=>"2-0", :car=>false, :bike=>false, :train=>true, :pedestrian=>true, :name=>"", :length_in_meter=>111302.53586533663, :geometry=>line_string("-1.0 1.0,0.0 1.0"), :boundary_id=>nil, :tags=>{}, :conditionnal_costs=>[["car", 1.7976931348623157e+308], ["bike", 1.7976931348623157e+308]], :junctions=>["4", "5"]},
    #                                                                            {:objectid=>"2-1", :car=>false, :bike=>false, :train=>true, :pedestrian=>true, :name=>"", :length_in_meter=>111319.4907932736, :geometry=>line_string("0.0 1.0,1.0 1.0"), :boundary_id=>boundary.id, :tags=>{}, :conditionnal_costs=>[["car", 1.7976931348623157e+308], ["bike", 1.7976931348623157e+308]], :junctions=>["5", "6-8-0"]},
    #                                                                            {:objectid=>"2-2", :car=>false, :bike=>false, :train=>true, :pedestrian=>true, :name=>"", :length_in_meter=>111319.49079327364, :geometry=>line_string("1.0 2.0,1.0 3.0"), :boundary_id=>boundary2.id, :tags=>{}, :conditionnal_costs=>[["car", 1.7976931348623157e+308], ["bike", 1.7976931348623157e+308]], :junctions=>["6-8-0", "6-8-1"]}] )
    # end
                                       
  end

  describe "#import" do

    after :each do
      subject.close_nodes_database
      subject.close_ways_database
    end
    
    it "should have import all nodes in a temporary nodes_database" do  
      subject.import
      ActiveRoad::PhysicalRoad.all.size.should == 8
      ActiveRoad::PhysicalRoad.all.collect(&:objectid).should =~ ["3-0", "3-1", "5-0", "5-1", "5-2", "6-0", "6-1", "6-2"]
      ActiveRoad::Boundary.all.size.should == 1
      ActiveRoad::Boundary.all.collect(&:objectid).should =~ ["73464"]
      ActiveRoad::PhysicalRoadConditionnalCost.all.size.should == 24
      ActiveRoad::Junction.all.size.should == 6
      ActiveRoad::Junction.all.collect(&:objectid).should =~ ["1", "2", "5", "8", "9", "10"]
      ActiveRoad::StreetNumber.all.size.should == 2
      ActiveRoad::StreetNumber.all.collect(&:objectid).should =~ ["2646260105", "2646260106"]
      ActiveRoad::LogicalRoad.all.size.should == 2  
      ActiveRoad::LogicalRoad.all.collect(&:name).should =~ ["Rue J. Symphorien", ""]
      ActiveRoad::JunctionsPhysicalRoad.all.size.should == 16
    end
  end

  describe "#backup_relations_pgsql" do

    after :each do
      subject.close_nodes_database
      subject.close_ways_database
    end
    
    it "should backup boundary" do      
      subject.backup_relations_pgsql
      ActiveRoad::Boundary.all.size.should == 1
      ActiveRoad::Boundary.first.objectid.should == "73464"
      ActiveRoad::Boundary.first.geometry.should == multi_polygon( [ polygon( point(-54.3, 5.3), point(-54.3, 5.4), point(-54.1, 5.4), point(-54.1, 5.3), point(-54.3, 5.3) ) ] )
    end

    # it "should order ways geometry" do
    #   let(:first) { line_string( "0 0,1 1" ) }
    #   let(:second) { line_string( "2 2,1 1" ) }
    #   let(:second_ordered) { line_string( "2 2,1 1" ) }
    #   let(:third) { line_string( "2 2,3 3" ) }
    #   expect(subject.order_ways_geometry( [first, second, last] )).to match_array( [first, second_ordered, third] )
    # end
    
  end

  describe "#backup_logical_roads_pgsql" do
    let!(:boundary) { create(:boundary) }

    it "should not create a logical road if physical road has no boundary" do
      physical_road = create(:physical_road, :boundary_id => nil)
      subject.backup_logical_roads_pgsql
      expect(ActiveRoad::LogicalRoad.all.size).to eq(0)
      expect(ActiveRoad::PhysicalRoad.all.collect(&:logical_road_id)).to match_array([nil])
    end
    
    it "should create a logical road with no name and a boundary if physical road has no name but a boundary" do
      physical_road = create(:physical_road, :boundary_id => boundary.id)
      subject.backup_logical_roads_pgsql
      expect(ActiveRoad::LogicalRoad.all.size).to eq(1)
      expect(ActiveRoad::LogicalRoad.first.attributes).to include( "boundary_id" => boundary.id )
      expect(ActiveRoad::PhysicalRoad.all.collect(&:logical_road_id)).to match_array(ActiveRoad::LogicalRoad.all.collect(&:id))
    end
    
    it "should create a logical road with no name and a boundary if physical roads has no name but a boundary" do
      physical_road = create(:physical_road, :boundary_id => boundary.id)
      physical_road2 = create(:physical_road, :boundary_id => boundary.id)
      subject.backup_logical_roads_pgsql
      expect(ActiveRoad::LogicalRoad.all.size).to eq(1)
      expect(ActiveRoad::LogicalRoad.first.attributes).to include( "boundary_id" => boundary.id )
      expect(ActiveRoad::PhysicalRoad.all.collect(&:logical_road_id)).to match_array([ActiveRoad::LogicalRoad.first.id, ActiveRoad::LogicalRoad.first.id])
    end

    it "should create a logical road with a name and a boundary if physical road has a name and a boundary" do
      physical_road = create(:physical_road, :boundary_id => boundary.id, :name => "Test")
      subject.backup_logical_roads_pgsql
      expect(ActiveRoad::LogicalRoad.all.size).to eq(1)
      expect(ActiveRoad::LogicalRoad.first.attributes).to include( "boundary_id" => boundary.id, "name" => "Test" )
      expect(ActiveRoad::PhysicalRoad.all.collect(&:logical_road_id)).to match_array([ActiveRoad::LogicalRoad.first.id])
    end

    it "should create one logical road with a name and a boundary if physical roads have same name and a boundary" do
      physical_road = create(:physical_road, :boundary_id => boundary.id, :name => "Test")
      physical_road = create(:physical_road, :boundary_id => boundary.id, :name => "Test")
      subject.backup_logical_roads_pgsql
      expect(ActiveRoad::LogicalRoad.all.size).to eq(1)
      expect(ActiveRoad::LogicalRoad.first.attributes).to include( "boundary_id" => boundary.id, "name" => "Test" )
      expect(ActiveRoad::PhysicalRoad.all.collect(&:logical_road_id)).to match_array([ActiveRoad::LogicalRoad.first.id, ActiveRoad::LogicalRoad.first.id])
    end
    
  end

end
