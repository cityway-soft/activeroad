require 'spec_helper'

describe ActiveRoad::TerraImporter do
  let(:xml_file) { File.expand_path("../../../fixtures/terra_minimal.xml", __FILE__) }
  
  subject { ActiveRoad::TerraImporter.new( xml_file ) } 
  
  describe "#import" do    
    it "should import all datas when split" do  
      subject.import
      expect(ActiveRoad::Junction.count).to eq(461)
      expect(ActiveRoad::StreetNumber.count).to eq(761)
      expect(ActiveRoad::PhysicalRoad.count).to eq(495)
      expect(ActiveRoad::PhysicalRoadConditionnalCost.count).to eq(1485)
      expect(ActiveRoad::JunctionsPhysicalRoad.count).to eq(975)     
    end    
  end

end
