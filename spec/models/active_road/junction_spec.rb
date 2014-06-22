require 'spec_helper'

describe ActiveRoad::Junction, :type => :model do

  subject { create(:junction_with_physical_roads) }
  
  it "should validate objectid uniqueness" do
    other = build :junction, :objectid => subject.objectid 
    expect(other).not_to be_valid
  end

  describe "#location_on_road" do
    it "should" do
      # TODO Understand the result
      expect(subject.location_on_road(subject.physical_roads.first)).to eq(25.577598616424485)
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
      expect(subject.access_to_road?(subject.physical_roads.first)).to be_truthy
      expect(subject.access_to_road?(create(:physical_road))).to be_falsey
    end
  end
  
  describe "#to_s" do
    it "should return junction description" do
      expect(subject.to_s).to eq("Junction @#{subject.geometry.lng},#{subject.geometry.lat}")
    end
  end

  describe "#name" do
    it "should return junction name" do
      expect(subject.name).to eq(subject.physical_roads.join(" - "))
    end
  end
  
end
