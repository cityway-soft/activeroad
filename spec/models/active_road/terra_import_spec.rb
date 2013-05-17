require 'spec_helper'

describe ActiveRoad::TerraImport do
  let(:xml_file) { File.expand_path("../../../fixtures/minimal.xml", __FILE__) }

  subject { ActiveRoad::TerraImport.new( xml_file ) } 

  before :each do 
    subject.import
  end

  it "should have import all logical roads" do   
    ActiveRoad::LogicalRoad.all.size.should == 4
  end

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
