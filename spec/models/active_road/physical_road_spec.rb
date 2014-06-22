require 'spec_helper'

describe ActiveRoad::PhysicalRoad, :type => :model do

  subject { create(:physical_road) }

  it "should validate objectid uniqueness" do
    other_road = build :physical_road, :objectid => subject.objectid 
    expect(other_road).not_to be_valid
  end

  it "should be valid with a logical_road" do
    subject.logical_road = nil
    expect(subject).to be_valid
  end

  describe ".nearest_to" do 
    let(:departure) { point(0, 0) }
    let!(:ab) { create(:physical_road, :geometry => line_string( "0.0001 0.0001,1 1" ) ) }
    let!(:ac) { create(:physical_road, :geometry => line_string( "-0.0001 -0.0001,-1 -1" ) )  }
    let!(:ad) { create(:physical_road, :geometry => line_string( "-0.001 -0.001,-1 -1" ) )  }
    
    it "should return physical roads in an area ordered from closest to farthest from a departure" do
      expect(ActiveRoad::PhysicalRoad.nearest_to(departure)).to eq([ab]) #[ab, ac]
    end
  end

end
