require 'spec_helper'

describe ActiveRoad::ShortestPath::Finder do

  let(:first_road) { Factory(:physical_road) }
  let(:second_road) { Factory(:physical_road) }
  let(:third_road) { Factory(:physical_road) }

  let(:source) { first_road.geometry.first.endpoint(90, 50) }
  let(:destination) { third_road.geometry.last.endpoint(0, 50) }
  
  let!(:first_junction) { Factory(:junction, :physical_roads => [first_road, second_road])}
  let!(:second_junction) { Factory(:junction, :physical_roads => [second_road, third_road])}

  subject { ActiveRoad::ShortestPath::Finder.new source, destination }

  it "should find a solution between first and last road" do
    subject.path.should_not be_blank
  end
  
end
