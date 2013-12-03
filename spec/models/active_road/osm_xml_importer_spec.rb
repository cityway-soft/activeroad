require 'spec_helper'

describe ActiveRoad::OsmXmlImporter do
  let(:xml_file) { File.expand_path("../../../fixtures/test.osm", __FILE__) }

  subject { ActiveRoad::OsmXmlImporter.new( xml_file, "/tmp/osm_xml_test.kch" ) } 

  describe "#extracted_tags" do
    it "should return an hash with tag_key => tag_value if tags size == 1" do 
      tags = double("tags", :size => 0, :attributes => {"k" => "highway", "v" => "primary"} )
      subject.extracted_tags(tags).should  == {"highway" => "primary"}
    end

    it "should return an hash with tag_key => tag_value if tags size >= 1" do 
      tags =  [ 
               double( :attributes => {"k" => "highway", "v" => "primary"}), 
               double( :attributes => {"k" => "highway", "v" => "pedestrian"}) 
              ]  
      subject.extracted_tags(tags).should  == {"highway" => "primary", "highway" => "pedestrian"}
    end

    it "should return an hash with tag_key => tag_value filtered with authorized tag_key" do 
      tags =  [ 
               double( :attributes => {"k" => "highway", "v" => "test"}), 
               double( :attributes => {"k" => "highway", "v" => "pedestrian"}) 
              ]  
      subject.extracted_tags(tags).should  == {"highway" => "pedestrian"}
    end
  end

  describe "#physical_road_conditionnal_costs" do
    let(:physical_road) { create(:physical_road) }

    it "should returnconditionnal cost with pedestrian, bike and train to infinity when tag key is car" do 
      ActiveRoad::PhysicalRoadConditionnalCost.should_receive(:new).exactly(3).times 
      subject.physical_road_conditionnal_costs({"highway" => "primary"})
    end

    it "should return nothing if tag key is not in ['highway', 'railway']" do   
      ActiveRoad::PhysicalRoadConditionnalCost.should_receive(:new).exactly(0).times 
      subject.physical_road_conditionnal_costs({"test" => "test"})
    end
  end

  describe "#backup_nodes" do
    before :each do 
      subject.open_database(subject.database_path)
    end

    after :each  do
      subject.close_database
    end

    it "should have import all nodes in a temporary database" do         
      subject.backup_nodes(subject.database)
      object = Marshal.load(subject.database.get(1))
      object.id.should ==  "1"
      object.lon.should == 0
      object.lat.should == 0
      object.ways.should == []
      object.end_of_way.should == false
    end
  end

  describe "#update_node_with_ways" do
    let(:way) { Saxerator::Builder::HashElement.new("Element", {"id" => "1"}) }
    
    before :each do 
      subject.open_database(subject.database_path)
      subject.database.set("1", Marshal.dump(ActiveRoad::OsmXmlImporter::Node.new("1", 2.0, 2.0)) )
      subject.database.set("2", Marshal.dump(ActiveRoad::OsmXmlImporter::Node.new("1", 2.0, 2.0)) )
      subject.database.set("3", Marshal.dump(ActiveRoad::OsmXmlImporter::Node.new("1", 2.0, 2.0)) )

      way["nd"] = [ 
                   double( :attributes => {"ref" => "1"}), 
                   double( :attributes => {"ref" => "2"}), 
                   double( :attributes => {"ref" => "3"}) 
                  ] 
    end

    after :each  do
      subject.close_database
    end

    it "should have update all nodes with way in the temporary database" do   
      subject.update_node_with_way(way, subject.database)
      node1 = Marshal.load(subject.database.get(1))
      node1.id.should ==  "1"
      node1.lon.should == 2.0
      node1.lat.should == 2.0
      node1.ways.should == ["1"]
      node1.end_of_way.should == true

      node2 = Marshal.load(subject.database.get(2))
      node2.id.should ==  "1"
      node2.lon.should == 2.0
      node2.lat.should == 2.0
      node2.ways.should == ["1"]
      node2.end_of_way.should == false

      node3 = Marshal.load(subject.database.get(3))
      node3.id.should ==  "1"
      node3.lon.should == 2.0
      node3.lat.should == 2.0
      node3.ways.should == ["1"]
      node3.end_of_way.should == true
    end
  end

  describe "#iterate_nodes" do
    let!(:point) { GeoRuby::SimpleFeatures::Point.from_x_y( 0, 0, 4326) }

    before :each do 
      subject.open_database(subject.database_path)
      subject.database.set("1", Marshal.dump(ActiveRoad::OsmXmlImporter::Node.new("1", 2.0, 2.0, ["1", "2"])) )
      subject.database.set("2", Marshal.dump(ActiveRoad::OsmXmlImporter::Node.new("2", 2.0, 2.0, ["1", "3"])) )
    end

    after :each  do
      subject.close_database
    end

    it "should iterate nodes to save it" do
      GeoRuby::SimpleFeatures::Point.stub :from_x_y => point
      subject.should_receive(:save_junctions).exactly(1).times.with([["1", point], ["2", point]], {"1" => ["1", "2"], "2" => ["1", "3"]})
      subject.iterate_nodes(subject.database)
    end
  end
  
  describe "#save_junctions" do

    let!(:physical_road) { create(:physical_road, :objectid => "1") }
    let!(:point) { GeoRuby::SimpleFeatures::Point.from_x_y( 0, 0, 4326) }

    it "should save junctions in postgresql database" do         
      junctions_values = [["1", point], ["2", point]]
      junctions_ways = {"1" => ["1"], "2" => ["1"]}

      subject.save_junctions(junctions_values, junctions_ways)

      ActiveRoad::Junction.all.size.should == 2
      first_junction = ActiveRoad::Junction.first
      first_junction.objectid.should == "1"
      first_junction.physical_roads.should == [physical_road]

      last_junction = ActiveRoad::Junction.last
      last_junction.objectid.should == "2"
      last_junction.physical_roads.should == [physical_road]
    end
  end  

  describe "#way_geometry" do
    let(:way) { Saxerator::Builder::HashElement.new("Element", {"id" => "1"}) }   
      
    before :each do 
      subject.open_database(subject.database_path)

      way["nd"] = [ 
                   double( :attributes => {"ref" => "1"}), 
                   double( :attributes => {"ref" => "2"}), 
                   double( :attributes => {"ref" => "3"}) 
                  ] 

      subject.database.set("1", Marshal.dump(ActiveRoad::OsmXmlImporter::Node.new("1", 0.0, 0.0, ["1", "2"])) )
      subject.database.set("2", Marshal.dump(ActiveRoad::OsmXmlImporter::Node.new("2", 1.0, 1.0, ["1", "3"])) )
      subject.database.set("3", Marshal.dump(ActiveRoad::OsmXmlImporter::Node.new("3", 2.0, 2.0, ["1", "3"])) )
    end

    after :each  do
      subject.close_database
    end   

    it "should update physical road geometry" do        
      subject.way_geometry(way, subject.database).should ==  GeoRuby::SimpleFeatures::LineString.from_points( [point(0.0,0.0), point(1.0,1.0), point(2.0,2.0) ])
    end

  end

  describe "#import" do
    it "should have import all nodes in a temporary database" do  
      subject.import
      ActiveRoad::PhysicalRoad.all.size.should == 2
      ActiveRoad::PhysicalRoadConditionnalCost.all.size.should == 6
      ActiveRoad::Junction.all.size.should == 4
    end
  end

  describe "#save_physical_roads_and_children" do
    let(:pr1) { ActiveRoad::PhysicalRoad.new :objectid => "physicalroad::1" }
    let(:pr2) { ActiveRoad::PhysicalRoad.new :objectid => "physicalroad::2" }
    let(:physical_roads) { [ pr1, pr2 ] }
    let(:prcc) { ActiveRoad::PhysicalRoadConditionnalCost.new :tags => "car", :cost => 0.3 }
    let(:physical_road_conditionnal_costs_by_objectid) { {pr1.objectid => [ [prcc] ]} }
    
    it "should save physical roads in postgresql database" do  
      subject.save_physical_roads_and_children(physical_roads)
      ActiveRoad::PhysicalRoad.all.size.should == 2
      ActiveRoad::PhysicalRoad.first.objectid.should == "physicalroad::1"
      ActiveRoad::PhysicalRoad.last.objectid.should == "physicalroad::2"
    end

    it "should save physical road conditionnal costs in postgresql database" do   
      subject.save_physical_roads_and_children(physical_roads, physical_road_conditionnal_costs_by_objectid)
      ActiveRoad::PhysicalRoadConditionnalCost.all.size.should == 1
      ActiveRoad::PhysicalRoadConditionnalCost.first.physical_road_id.should == ActiveRoad::PhysicalRoad.first.id
    end
  end

  describe ActiveRoad::OsmXmlImporter::Node do
    
    let(:subject) { ActiveRoad::OsmXmlImporter::Node.new(122323131, 34.2, 12.5) } 

    it "should return a node object when unmarhalling a dump of node object" do
      data = Marshal.dump(subject)
      object = Marshal.load(data)
      object.should be_an_instance_of(ActiveRoad::OsmXmlImporter::Node)
      object.id.should == subject.id
      object.lon.should == subject.lon
      object.lat.should == subject.lat
      object.ways.should == subject.ways
    end

    it "should return a node object with ways when we add a way" do
      subject.add_way(1223344)
      data = Marshal.dump(subject)
      object = Marshal.load(data)
      object.should be_an_instance_of(ActiveRoad::OsmXmlImporter::Node)
      object.id.should == subject.id
      object.lon.should == subject.lon
      object.lat.should == subject.lat
      object.ways.should == [ 1223344 ]
    end

  end

end
