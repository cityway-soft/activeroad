require 'spec_helper'

describe ActiveRoad::ShortestPath::Finder do

  let(:first_road) { create(:physical_road, :objectid => "1",:geometry => line_string("0 0, 1 1"), :tags => {:speed => "10"}) }
  let(:second_road) { create(:physical_road, :objectid => "2", :geometry => line_string("1 1, 2 2"), :tags => {:speed => "100"}) }
  let(:third_road) { create(:physical_road, :objectid => "3", :geometry => line_string("2 2, 3 3"), :tags => {:speed => "100"}) }

  let(:second_road_bis) { create(:physical_road, :objectid => "2bis", :geometry => line_string("1 1, 3 1, 3 3"), :tags => {:speed => "10"}) }

  let(:source) { first_road.geometry.first.endpoint(90, 50) }
  let(:destination) { third_road.geometry.last.endpoint(0, 50) }
  
  let!(:first_junction) { create(:junction, :geometry => point(1, 1), :physical_roads => [first_road, second_road, second_road_bis])}
  let!(:second_junction) { create(:junction, :geometry => point(2, 2), :physical_roads => [second_road, third_road])}
  let!(:third_junction) { create(:junction, :geometry => point(3, 3), :physical_roads => [ third_road])}

  it "should find a solution between first and last road" do
    subject = ActiveRoad::ShortestPath::Finder.new source, destination
    subject.path.should_not be_blank
    subject.path.size.should == 7
    subject.path[3].physical_road.objectid.should == "2"
  end

  it "should find a solution between first and last road with specific tags" do
    subject = ActiveRoad::ShortestPath::Finder.new source, destination, {:speed => "100"}
    subject.path.should_not be_blank
    subject.path.size.should == 6
    subject.path[3].physical_road.objectid.should == "2bis"
  end

  it "should find a solution between first and last road with specific kind" do
                                                                               
  end  
end
