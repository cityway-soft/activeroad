require 'spec_helper'

describe ActiveRoad::ShortestPath::Finder do

  let(:first_road) { create(:physical_road, :geometry => line_string("0 0, 1 1")) }
  let(:second_road) { create(:physical_road, :geometry => line_string("1 1, 2 2")) }
  let(:third_road) { create(:physical_road, :geometry => line_string("2 2, 3 3")) }

  let(:source) { first_road.geometry.first.endpoint(90, 50) }
  let(:destination) { third_road.geometry.last.endpoint(0, 50) }
  
  let!(:first_junction) { create(:junction, :geometry => point(1, 1), :physical_roads => [first_road, second_road])}
  let!(:second_junction) { create(:junction, :geometry => point(2, 2), :physical_roads => [second_road, third_road])}
  let!(:third_junction) { create(:junction, :geometry => point(3, 3), :physical_roads => [ third_road])}

  subject { ActiveRoad::ShortestPath::Finder.new source, destination }

  it "should find a solution between first and last road" do
    subject.path.should_not be_blank
  end
  
end
