require 'spec_helper'

describe ActiveRoad::OsmImport do
  let(:xml_file) { File.expand_path("../../../fixtures/test.osm", __FILE__) }
  #let(:bzip_file) { File.expand_path("../../../fixtures/test.osm.bz2", __FILE__) }
  #let(:xml_file) { File.expand_path("/home/luc/Documents/cityway/spot/donnees/osm/se.osm", __FILE__) }

  # TODO : Switch between bz2 and normal files
  subject { ActiveRoad::OsmImport.new( xml_file ) } 

  describe "#transport_modes" do
    it "should return car when highway and tag value for car" do 
      subject.transport_modes("highway", "primary").should  == ["car"]
    end

    it "should return bike when highway and tag value for bike" do   
      subject.transport_modes("highway", "cycleway").should  == ["bike"]
    end

    it "should return pedestrian when highway and tag value for pedestrian" do   
      subject.transport_modes("highway", "pedestrian").should  == ["pedestrian", "bike"]
    end

    it "should return train when railway and tag value for train" do  
      subject.transport_modes("railway", "rail").should  == ["train"]
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
      object. ways.should == []
    end
  end

  describe "#update_node_with_ways" do
    before :each do 
      subject.open_database(subject.database_path)
      subject.backup_nodes(subject.database)
    end

    after :each  do
      subject.close_database
    end

    it "should have update all nodes with ways in the temporary database" do   
      subject.update_node_with_ways(subject.database)
      object = Marshal.load(subject.database.get(1))
      object.id.should ==  "1"
      object.lon.should == 0
      object.lat.should == 0
      object. ways.should == ["3"]
    end

    it "should save ways in the database" do   
      subject.update_node_with_ways(subject.database)
      ActiveRoad::PhysicalRoad.all.size.should == 2
      ActiveRoad::PhysicalRoad.first.objectid = "3"
    end
  end

  describe "#save_physical_roads" do
    it "should save physical roads in postgresql database" do   
      physical_roads_values = [["1"], ["2"]]
      subject.save_physical_roads(physical_roads_values)
      ActiveRoad::PhysicalRoad.all.size.should == 2
      ActiveRoad::PhysicalRoad.first.objectid.should == "1"
      ActiveRoad::PhysicalRoad.last.objectid.should == "2"
    end
  end

  describe "#iterate_nodes" do
    before :each do 
      subject.open_database(subject.database_path)
    end

    after :each  do
      subject.close_database
    end

    it "should iterate nodes to save it" do
      subject.iterate_nodes(subject.database)
      # TODO
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
    it "should have import all nodes in a temporary database" do   
      subject.import
      # TODO
    end
  end

  describe ActiveRoad::OsmImport::Node do
    
    let(:subject) { ActiveRoad::OsmImport::Node.new(122323131, 34.2, 12.5) } 

    it "should return a node object when unmarhalling a dump of node object" do
      data = Marshal.dump(subject)
      object = Marshal.load(data)
      object.should be_an_instance_of(ActiveRoad::OsmImport::Node)
      object.id.should == subject.id
      object.lon.should == subject.lon
      object.lat.should == subject.lat
      object.ways.should == subject.ways
    end

    it "should return a node object with ways when we add a way" do
      subject.add_way(1223344)
      data = Marshal.dump(subject)
      object = Marshal.load(data)
      object.should be_an_instance_of(ActiveRoad::OsmImport::Node)
      object.id.should == subject.id
      object.lon.should == subject.lon
      object.lat.should == subject.lat
      object.ways.should == [ 1223344 ]
    end

  end

end
