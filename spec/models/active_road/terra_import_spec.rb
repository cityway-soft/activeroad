require 'spec_helper'

describe ActiveRoad::TerraImport do

  describe "test big xml file" do
    let(:xml_file) { File.expand_path("../../../fixtures/terra.xml", __FILE__) }
    
    subject { ActiveRoad::TerraImport.new( xml_file ) } 
    
    before :each do 
      subject.extract
    end
    
    # it "should have import all logical roads" do   
    #   ActiveRoad::LogicalRoad.all.size.should == 4
    # end
    
    it "should have import all physical roads" do
      ActiveRoad::PhysicalRoad.all.size.should == 78
    end
    
    it "should have import all junctions" do
      ActiveRoad::Junction.all.size.should == 70
    end
    
    it "should have import all street number" do
      ActiveRoad::StreetNumber.all.size.should == 20
    end
  end

  describe "test minimal xml file" do
    let(:xml_file) { File.expand_path("../../../fixtures/terra_minimal.xml", __FILE__) }
    
    subject { ActiveRoad::TerraImport.new( xml_file ) } 
    
    before :each do 
      subject.extract
    end

    it "should have import one physical road" do
      ActiveRoad::PhysicalRoad.all.size.should == 1
      
      physical_road = ActiveRoad::PhysicalRoad.first  
    
      physical_road.objectid.should == "ign-obj-205"
    end
    
    it "should have import 2 junctions" do
      ActiveRoad::Junction.all.size.should == 2

      junction1 = ActiveRoad::Junction.first
      junction2 = ActiveRoad::Junction.last

      junction1.objectid.should == "ign-obj-55"
      junction1.physical_roads.first.objectid.should == "ign-obj-205"
      junction2.objectid.should == "ign-obj-56"
      junction2.physical_roads.first.objectid.should == "ign-obj-205"
    end    
  end

end

describe ActiveRoad::TerraImport::TrajectoryNodeXml do
  let(:trajectory_node_xml) { File.expand_path("../../../fixtures/trajectory_node.xml", __FILE__) }
  let(:parser) { Saxerator.parser(File.new(trajectory_node_xml)) }
  
  let(:trajectory_node) { ActiveRoad::TerraImport::TrajectoryNodeXml.new(parser.for_tag(:TrajectoryNode).first) }

  it "should have an object id" do
    trajectory_node.objectid.should == "ign-obj-93"
  end

  it "should have tags" do
    trajectory_node.tags.should == {}
  end
  
  it "should have a geometry" do
    trajectory_node.geometry.should_not be_nil
  end
  
  # it "should have an height" do
  #   trajectory_node.height.should == 5
  # end

end

describe ActiveRoad::TerraImport::TrajectoryArcXml do
  let(:trajectory_arc_xml) { File.expand_path("../../../fixtures/trajectory_arc.xml", __FILE__) }
  let(:parser) { Saxerator.parser(File.new(trajectory_arc_xml)) }
  
  let(:trajectory_arc) { ActiveRoad::TerraImport::TrajectoryArcXml.new(parser.for_tag(:TrajectoryArc).first) }

  it "should have an object id" do
    trajectory_arc.objectid.should == "ign-obj-132"
  end

  it "should have tags" do
    trajectory_arc.tags.should == {}
  end
  
  it "should have a geometry" do
    trajectory_arc.geometry.should_not be_nil
  end

  it "should have a minimum width" do
    trajectory_arc.minimum_width.should == "wide"
  end
  
  it "should have a length in meter" do
    trajectory_arc.length.should == "62.59449394845691"
  end
  
end
