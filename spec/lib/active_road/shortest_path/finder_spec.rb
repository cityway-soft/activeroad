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
  let!(:e) { create(:junction, :geometry => point(0, 2), :physical_roads => [ ce, ef ] ) }
  let!(:f) { create(:junction, :geometry => point(1, 2), :physical_roads => [ ef, df, cf ] ) }

  it "should find a solution between first and last road" do
    subject = ActiveRoad::ShortestPath::Finder.new departure, arrival, 4
    subject.path.should_not be_blank
    subject.path.size.should == 6
    subject.path[2].physical_road.objectid.should == "ac"
    subject.path[3].physical_road.objectid.should == "cf"
  end

  describe "Shortest path with constraints" do       
    
    it "should find a solution between first and last road with no forbidden tags" do
      subject = ActiveRoad::ShortestPath::Finder.new departure, arrival, 4, constraints
      subject.path.should_not be_blank
      subject.path.size.should == 8
      subject.path[2].physical_road.objectid.should == "ac"
      subject.path[3].physical_road.objectid.should == "ce"
      subject.path[4].physical_road.objectid.should == "ef"
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


  describe "#path_weights" do       
    
    let(:subject) { ActiveRoad::ShortestPath::Finder.new departure, arrival, 4 }
    
    it "should return 0 if no physical road" do
      path = departure 
      subject.path_weights(path).should == 0
    end
    
    it "should return path weights" do     
      path = ActiveRoad::Path.new(:departure => create(:junction), :physical_road => create(:physical_road) ) 
      path.stub :length_in_meter => 2
      subject.path_weights(path).should == 2 / (4 * 1000/3600)
    end

    it "should return path weights and node weight" do
      path = ActiveRoad::Path.new(:departure => create(:junction, :waiting_constraint => 2.5), :physical_road => create(:physical_road) )
      path.stub :length_in_meter => 2
      subject.path_weights(path).should == 2 / (4 * 1000/3600) + 2.5
    end

  end

  describe "#refresh_context" do
    let(:subject) { ActiveRoad::ShortestPath::Finder.new departure, arrival, 4 }

    it "should increase uphill if node is a junction and has an uphill value" do
      node = create(:physical_road, :uphill => 3)
      context = {:uphill => 3}
      subject.refresh_context(node, context).should == { :uphill => 6}      
    end

    it "should not increase uphill if node is not a junction" do
      node = create(:physical_road)
      context = {:uphill => 3}
      subject.refresh_context(node, context).should == { :uphill => 3}
    end

    it "should set context uphill to 0 if node is not a junction and no previous context" do 
      node = create(:physical_road)
      context = {}
      subject.refresh_context(node, context).should == { :uphill => 0}
    end
  end


  describe "#follow_way" do       
    
    let(:node) { mock(:node) }
    let(:destination) { mock(:destination) }
    let(:weight) { 2 }
    let(:context) { {:uphill => 2} }
    let(:subject) { ActiveRoad::ShortestPath::Finder.new departure, arrival, 4 }

    before(:each) do 
      subject.stub :search_heuristic => 1
      subject.stub :time_heuristic => 2
    end
    
    it "should not follow way if uphill > uphill max" do     
      subject.constraints = {:uphill => 1}
      subject.follow_way?(node, destination, weight, context).should be_false
    end

    it "should follow way if uphill < uphill max" do
      subject.constraints = {:uphill => 3}
      subject.follow_way?(node, destination, weight, context).should be_true
    end

  end
  
end
