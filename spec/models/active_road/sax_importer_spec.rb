require 'spec_helper'

describe ActiveRoad::SaxImporter do
  let(:xml_file) { File.expand_path("../../../fixtures/minimal.xml", __FILE__) }

  subject { ActiveRoad::SaxImporter.new( xml_file ) } 

  it "should have import all logical roads" do
    subject.import
    ActiveRoad::LogicalRoad.all.size.should == 3
  end

  it "should have import all physical roads" do
    subject.import
    ActiveRoad::PhysicalRoad.all.size.should == 3
  end

  it "should have import all junctions" do
    subject.import
    ActiveRoad::Junction.all.size.should == 1
  end

  it "should have import all street number" do
    subject.import
    ActiveRoad::StreetNumber.all.size.should == 1
  end

end
