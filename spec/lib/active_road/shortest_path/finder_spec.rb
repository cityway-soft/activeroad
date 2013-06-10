require 'spec_helper'

describe ActiveRoad::ShortestPath::Finder do

  #
  #  
  #
  #
  #
  #
  #
  #
  #  
  #  

  let(:source) { ab.geometry.first.endpoint(90, 50) }
  let(:destination) { cd.geometry.last.endpoint(0, 50) }

  let(:ab) { create(:physical_road, :objectid => "ab",:geometry => line_string("0 0, 1 1"), :tags => {:speed => "10"}) }
  let(:bc) { create(:physical_road, :objectid => "bc", :geometry => line_string("1 1, 2 2"), :tags => {:speed => "100"}) }
  let(:cd) { create(:physical_road, :objectid => "cd", :geometry => line_string("2 2, 3 3"), :tags => {:speed => "100"}) }

  let(:be) { create(:physical_road, :objectid => "ae", :geometry => line_string("1 1, 3 1"), :tags => {:speed => "10"}) }    
  let(:ed) { create(:physical_road, :objectid => "ef", :geometry => line_string("3 1, 3 3"), :tags => {:speed => "10"}) }
  
  let!(:a) { create(:junction, :geometry => point(0, 0), :physical_roads => [ ab ] )}
  let!(:b) { create(:junction, :geometry => point(1, 1), :physical_roads => [ ab, bc, be ] )}
  let!(:c) { create(:junction, :geometry => point(2, 2), :physical_roads => [ bc, cd ] )}   
  let!(:d) { create(:junction, :geometry => point(3, 3), :physical_roads => [ cd, ed ] )}   
  let!(:e) { create(:junction, :geometry => point(3, 1), :physical_roads => [ be, ed ])}

  it "should find a solution between first and last road" do
    subject = ActiveRoad::ShortestPath::Finder.new source, destination, 4
    subject.path.should_not be_blank
    subject.path.size.should == 7
    subject.path[3].physical_road.objectid.should == "bc"
    subject.path[4].physical_road.objectid.should == "cd"
  end

  describe "Shortest path with forbidden tags" do       
    
    it "should find a solution between first and last road with no forbidden tags" do
      subject = ActiveRoad::ShortestPath::Finder.new source, destination, 4, {:speed => "100"}
      subject.path.should_not be_blank
      subject.path.size.should == 7
      subject.path[3].physical_road.objectid.should == "ae"
      subject.path[4].physical_road.objectid.should == "ef"
    end

  end

  describe "Shortest path with weights" do

    it "should find a solution between first and last road with weights" do
      subject = ActiveRoad::ShortestPath::Finder.new source, destination, 4, {}, {"speed" => [90, 110, 0.5]}
      subject.path.should_not be_blank
      subject.path.size.should == 8
      subject.path[3].physical_road.objectid.should == "ae"
      subject.path[4].physical_road.objectid.should == "ef"
    end

  end
  
end
