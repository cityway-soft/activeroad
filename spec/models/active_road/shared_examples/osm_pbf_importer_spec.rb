shared_examples "an OsmPbfImporter module" do 

  describe "#save_junctions" do
    let!(:point) { geos_factory.point( 0, 0) }

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
      subject_without_data.save_junctions
      expect(ActiveRoad::Junction.all.collect(&:objectid)).to match_array(["1", "2"])
    end
  end  

  describe "#save_physical_roads" do
    let!(:line) { geos_factory.parse_wkt( "LINESTRING(0 0,2 2)" ) }
    let!(:line2) { geos_factory.parse_wkt( "LINESTRING(2 2,3 3)" ) }
    let!(:junction1) { create(:junction, :objectid => "1", :geometry => geos_factory.point(0, 0) ) }
    let!(:junction2) { create(:junction, :objectid => "2", :geometry => geos_factory.point(2, 2) ) }
    let!(:junction3) { create(:junction, :objectid => "3", :geometry => geos_factory.point(3, 3) ) }
    let!(:boundary) { create(:boundary, :geometry => geos_factory.parse_wkt( "MULTIPOLYGON(((0 0,2 0,2 2,0 2)))") ) }
    
    before :each do
      subject_without_data.nodes_database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("1", 0.0, 0.0, "", ["1", "2"])) )
      subject_without_data.nodes_database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("2", 2.0, 2.0, "", ["1", "3"])) )
      subject_without_data.nodes_database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("3", 3.0, 3.0, "", ["1", "3"])) )
      subject_without_data.ways_database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Way.new("1-0", ["1", "2", "3"], true, false, false, false, "Test", "100", true, "", "", "", "", {"highway" =>  "secondary", "cycleway" => "lane"}) ) )
      subject_without_data.ways_database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Way.new("2-0", ["1", "2"], true, false, false, false, "Test", "100", true, "", "", "", "", {"highway" =>  "secondary", "toll" => "true"}) ) )
      subject_without_data.ways_database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Way.new("3-0", ["1", "2"], true, false, false, false, "Test", "100", true, "", "", "", "", {"highway" =>  "secondary"}) ) )
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
      subject_without_data.save_physical_roads
      expect(ActiveRoad::PhysicalRoad.all.collect(&:objectid)).to match_array(["1-0", "2-0", "3-0"]
)
    end
  end

  describe "#physical_road_conditionnal_costs" do
    let(:physical_road) { create(:physical_road) }

    it "should return conditionnal cost with pedestrian, bike and train to infinity when tag key is car" do
      expect(importer.physical_road_conditionnal_costs( ActiveRoad::OsmPbfImporterLevelDb::Way.new("", [], true) )).to eq([["pedestrian", Float::MAX], ["bike", Float::MAX], ["train", Float::MAX]])
    end

    it "should return conditionnal cost with pedestrian, bike, car and train to infinity when tag key is nothing" do   
      expect(importer.physical_road_conditionnal_costs( ActiveRoad::OsmPbfImporterLevelDb::Way.new("", []) )).to eq([ ["car", Float::MAX], ["pedestrian", Float::MAX], ["bike", Float::MAX], ["train", Float::MAX]])
    end
  end

  describe "#backup_relations_pgsql" do

    before :each do
      subject.nodes_database
      subject.ways_database
      
      subject.backup_nodes
      subject.backup_ways
    end
    
    after :each do
      subject.close_nodes_database
      subject.delete_nodes_database
      subject.close_ways_database
      subject.delete_ways_database
    end
    
    it "should backup boundary" do      
      subject.backup_relations_pgsql
      expect(ActiveRoad::Boundary.all.size).to eq(1)
      expect(ActiveRoad::Boundary.first.objectid).to eq("73464")
      expect(ActiveRoad::Boundary.first.geometry).to eq(geos_factory.parse_wkt( "MULTIPOLYGON(((-54.3 5.3,-54.3 5.4,-54.1 5.4,-54.1 5.3,-54.3 5.3 ) ))" ) )
    end

    # it "should order ways geometry" do
    #   let(:first) { line_string( "0 0,1 1" ) }
    #   let(:second) { line_string( "2 2,1 1" ) }
    #   let(:second_ordered) { line_string( "2 2,1 1" ) }
    #   let(:third) { line_string( "2 2,3 3" ) }
    #   expect(subject.order_ways_geometry( [first, second, last] )).to match_array( [first, second_ordered, third] )
    # end
    
  end

  describe "#save_street_numbers_from_nodes" do
    let!(:point) { geos_factory.point( 0, 0) }

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
      subject_without_data.save_street_numbers_from_nodes
      expect(ActiveRoad::StreetNumber.all.collect(&:objectid)).to match_array(["3"])
    end
  end

  describe "#save_street_numbers_from_ways" do
    
    before :each do           
      subject_without_data.nodes_database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("1", 0, 0.0001, "1", ["1"], true, {"addr:street" => "Avenue de l'ile"})) )
      subject_without_data.nodes_database.put("2", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("2", 0.5, 0.0001, "", ["1"])) )
      subject_without_data.nodes_database.put("3", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Node.new("3", 1, 0.0001, "5", ["1"], true, {})) )
      subject_without_data.ways_database.put("1", Marshal.dump(ActiveRoad::OsmPbfImporterLevelDb::Way.new("1", ["1", "2", "3"], true, false, false, false, "Test", "100", true, "", "", "", "even", {"cycleway" => "lane"}) ) )
    end

    after :each do
      subject_without_data.nodes_database.delete("1")
      subject_without_data.nodes_database.delete("2")
      subject_without_data.nodes_database.delete("3")

      subject_without_data.ways_database.delete("1")

      subject_without_data.close_nodes_database
      subject_without_data.close_ways_database
    end

    it "should save street number from ways" do
      physical_road = create(:physical_road, :geometry => geos_factory.parse_wkt("SRID=4326;LINESTRING(0 0, 1 0)")) 
      subject_without_data.save_street_numbers_from_ways

      expect(ActiveRoad::StreetNumber.count).to eq(2)
      expect(ActiveRoad::StreetNumber.first).to have_attributes( :objectid => "1", :physical_road_id => physical_road.id, :location_on_road => 0.0 )
    end

    it "should save street number from ways" do
      physical_road = create(:physical_road, :name => "Avenue de l'ile", :geometry => geos_factory.parse_wkt("SRID=4326;LINESTRING(0 0, 1 0)")) 
      subject_without_data.save_street_numbers_from_ways

      expect(ActiveRoad::StreetNumber.count).to eq(2)
      expect(ActiveRoad::StreetNumber.first).to have_attributes( :objectid => "1", :physical_road_id => physical_road.id, :location_on_road => 0.0 )
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

  describe "#split_way_with_boundaries" do        
    let!(:boundary) { create(:boundary, :geometry => "MULTIPOLYGON(((0 0,2 0,2 2,0 2,0 0)))" ) }
    let!(:boundary2) { create(:boundary, :geometry => "MULTIPOLYGON(((0 2,2 2,2 4,0 4,0 2)))" ) }
    
    it "should split way in three parts" do
      physical_road = create(:physical_road, :geometry => "LINESTRING(-1.0 1.0, 1.0 1.0, 1.0 2.0, 1.0 3.0)", :boundary_id => nil, :tags => {"bridge" => "true", "first_node_id" => "1", "last_node_id" => "2"})
      departure = create(:junction, :geometry => geos_factory.point(-1.0, 1.0))
      arrival = create(:junction, :geometry => geos_factory.point(1.0, 3.0))
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
      physical_road = create(:physical_road, :geometry => "LINESTRING(-1.0 1.0, 1.0 1.0, 1.0 2.0, -1.0 2.0)", :boundary_id => nil)
      departure = create(:junction, :geometry => geos_factory.point(-1.0, 1.0))
      arrival = create(:junction, :geometry => geos_factory.point(-1.0, 2.0))
      physical_road.junctions << [departure, arrival]
      
      subject_without_data.split_way_with_boundaries
      expect(ActiveRoad::PhysicalRoad.all.size).to eq(4)
    end

    it "should update boundary_id" do
      physical_road = create(:physical_road, :geometry => "LINESTRING(0.0 1.0,1.0 1.0)", :boundary_id => nil)
      departure = create(:junction, :geometry => geos_factory.point(0.0, 1.0))
      arrival = create(:junction, :geometry => geos_factory.point(1.0, 1.0))
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
