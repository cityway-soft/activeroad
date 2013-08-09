require 'spec_helper'

describe ActiveRoad::ShortestPath::Finder do

  #        Path schema
  #
  #    E-----------------F    
  #    | _______________/|
  #    |/                |
  #    C-----------------D
  #    |                 |
  #    |                 |
  #    A-----------------B 
  #  

  let(:departure) { point(0, 0) }
  let(:arrival) { point(1, 2) }
  let(:speed) { 4 }
  let(:constraints) { {:transport_mode => [:pedestrian, nil]} }

  let(:ab) { create(:physical_road, :objectid => "ab", :geometry => line_string( "0 0,1 0" ) ) }
  let(:cd) { create(:physical_road, :objectid => "cd", :geometry => line_string( "0 1,1 1" ) ) }
  let(:ef) { create(:physical_road, :objectid => "ef", :geometry => line_string( "0 2,1 2" ) ) }
  let(:ac) { create(:physical_road, :objectid => "ac", :geometry => line_string( "0 0,0 1" ) ) }
  let(:bd) { create(:physical_road, :objectid => "bd", :geometry => line_string( "1 0,1 1" ) ) }
  let(:ce) { create(:physical_road, :objectid => "ce", :geometry => line_string( "0 1,0 2" ) ) }
  let(:df) { create(:physical_road, :objectid => "df", :geometry => line_string( "1 1,1 2" ) ) }
  let(:cf) { create(:physical_road, :objectid => "cf", :geometry => line_string( "0 1,1 2" ), :transport_mode => :bike ) }

  let!(:a) { create(:junction, :geometry => point(0, 0), :physical_roads => [ ab, ac ] ) }
  let!(:b) { create(:junction, :geometry => point(1, 0), :physical_roads => [ ab, bd ] ) }
  let!(:c) { create(:junction, :geometry => point(0, 1), :physical_roads => [ cd, ac, ce, cf ] ) }
  let!(:d) { create(:junction, :geometry => point(1, 1), :physical_roads => [ cd, bd, df ] ) }
  let!(:e) { create(:junction, :geometry => point(0, 2), :physical_roads => [ ab, ac ] ) }
  let!(:f) { create(:junction, :geometry => point(1, 2), :physical_roads => [ ef, df, cf ] ) }

  it "should find a solution between first and last road" do
    subject = ActiveRoad::ShortestPath::Finder.new departure, arrival, 4
    subject.path.should_not be_blank
    subject.path.size.should == 7
    subject.path[3].physical_road.objectid.should == "ac"
    subject.path[4].physical_road.objectid.should == "cf"
  end

  describe "Shortest path with constraints" do       
    
    it "should find a solution between first and last road with no forbidden tags" do
      subject = ActiveRoad::ShortestPath::Finder.new departure, arrival, 4, constraints
      subject.path.should_not be_blank
      subject.path.size.should == 8
      subject.path[3].physical_road.objectid.should == "ac"
      subject.path[4].physical_road.objectid.should == "cd"
      subject.path[5].physical_road.objectid.should == "df"
    end

  end

  # describe "Shortest path with weights" do

  #   it "should find a solution between first and last road with weights" do
  #     subject = ActiveRoad::ShortestPath::Finder.new source, destination, 4
  #     subject.path.should_not be_blank
  #     subject.path.size.should == 7
  #     subject.path[3].physical_road.objectid.should == "bc"
  #     subject.path[4].physical_road.objectid.should == "cd"
  #   end

  # end
  
end
