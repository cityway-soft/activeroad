require 'spec_helper'

describe ActiveRoad::Junction do

  subject { create(:junction_with_physical_roads) } 
  
  it "should validate objectid uniqueness" do
    other = build :junction, :objectid => subject.objectid 
    other.should_not be_valid
  end

  describe "#location_on_road" do
    it "should" do
      ac = create(:physical_road, :geometry => "LINESTRING(0 0, 1 0)" )
      b = create(:junction, :geometry => "POINT(0.5 2)")
      b.location_on_road(ac).should == 0.5
    end
  end

  describe "#paths" do
    it "should return paths from junction" do
      subject.physical_roads.each do |physical_road|
        physical_road.junctions << create(:junction)
      end
      expect(subject.paths.size).to eq(2)
      expect(subject.paths.collect(&:physical_road).flatten).to match_array(subject.physical_roads)
    end
  end

  describe "#access_on_road" do
    it "should return if junction access to road or not" do
      subject.access_to_road?(subject.physical_roads.first).should be_true
      subject.access_to_road?(create(:physical_road)).should be_false
    end
  end
  
  describe "#to_s" do
    it "should return junction description" do
      subject.to_s.should == "Junction @#{subject.geometry.x},#{subject.geometry.y}"
    end
  end

  describe "#name" do
    it "should return junction name" do
      subject.name.should == subject.physical_roads.join(" - ")
    end
  end
  
end
