require 'spec_helper'

describe ActiveRoad::TerraImporter do
  let(:xml_file) { File.expand_path("../../../fixtures/terra.xml", __FILE__) }
  
  subject { ActiveRoad::TerraImporter.new( xml_file, "/tmp/terra_test.kch" ) } 

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
      object = Marshal.load(subject.database.get("ign-obj-100"))
      object.id.should ==  "ign-obj-100"
      object.geometry.should == "SRID=4326;POINT(2.331932632740265 48.85215698894743)"
      object.ways.should == ["ign-obj-184", "ign-obj-204"]
      object.end_of_way.should == false
    end
  end

  describe "#iterate_nodes" do
    let!(:point) { GeoRuby::SimpleFeatures::Point.from_x_y( 2.331932632740265, 48.85215698894743, 4326) }

    before :each do 
      subject.open_database(subject.database_path)
      subject.database.set("1", Marshal.dump(ActiveRoad::TerraImporter::Node.new("1", "SRID=4326;POINT(2.331932632740265 48.85215698894743)", ["1", "2"])) )
      subject.database.set("2", Marshal.dump(ActiveRoad::TerraImporter::Node.new("2", "SRID=4326;POINT(2.331932632740265 48.85215698894743)", ["1", "3"])) )
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

  describe "#import" do     
    
    it "should have import all physical roads" do
      subject.import
      ActiveRoad::PhysicalRoad.all.size.should == 78
      ActiveRoad::Junction.all.size.should == 70
      #ActiveRoad::StreetNumber.all.size.should == 20
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

  describe ActiveRoad::TerraImporter::Node do
    
    let(:subject) { ActiveRoad::TerraImporter::Node.new("ign-obj-100", "SRID=4326;POINT(2.331932632740265 48.85215698894743") } 

    it "should return a node object when unmarhalling a dump of node object" do
      data = Marshal.dump(subject)
      object = Marshal.load(data)
      object.should be_an_instance_of(ActiveRoad::TerraImporter::Node)
      object.id.should == subject.id
      object.geometry.should == subject.geometry
      object.ways.should == subject.ways
    end

    it "should return a node object with ways when we add a way" do
      subject.add_way("1223344")
      data = Marshal.dump(subject)
      object = Marshal.load(data)
      object.should be_an_instance_of(ActiveRoad::TerraImporter::Node)
      object.id.should == subject.id
      object.geometry.should == subject.geometry
      object.ways.should == [ "1223344" ]
    end

  end
  
end
