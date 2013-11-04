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

  let(:departure) { point(-0.1, 0.1) }
  let(:arrival) { point(1, 2) }
  let(:speed) { 4 }
  let(:constraints) { ["bike"] }

  let!(:ab) { create(:physical_road, :objectid => "ab", :geometry => line_string( "0 0,1 0" ) ) }
  let!(:cd) { create(:physical_road, :objectid => "cd", :geometry => line_string( "0 1,1 1" ) ) }
  let!(:ef) { create(:physical_road, :objectid => "ef", :geometry => line_string( "0 2,1 2" ) ) }
  let!(:ac) { create(:physical_road, :objectid => "ac", :geometry => line_string( "0 0,0 1" ) ) }
  let!(:bd) { create(:physical_road, :objectid => "bd", :geometry => line_string( "1 0,1 1" ) ) }
  let!(:ce) { create(:physical_road, :objectid => "ce", :geometry => line_string( "0 1,0 2" ) ) }
  let!(:df) { create(:physical_road, :objectid => "df", :geometry => line_string( "1 1,1 2" ) ) }
  let!(:cf) { create(:physical_road, :objectid => "cf", :geometry => line_string( "0 1,1 2" ) ) }

  let!(:a) { create(:junction, :geometry => point(0, 0), :physical_roads => [ ab, ac ] ) }
  let!(:b) { create(:junction, :geometry => point(1, 0), :physical_roads => [ ab, bd ] ) }
  let!(:c) { create(:junction, :geometry => point(0, 1), :physical_roads => [ cd, ac, ce, cf ] ) }
  let!(:d) { create(:junction, :geometry => point(1, 1), :physical_roads => [ cd, bd, df ] ) }
  let!(:e) { create(:junction, :geometry => point(0, 2), :physical_roads => [ ce, ef ] ) }
  let!(:f) { create(:junction, :geometry => point(1, 2), :physical_roads => [ ef, df, cf ] ) }

  describe "#path" do       

    it "should find a solution between first and last road with with no constraints" do
      path = ActiveRoad::ShortestPath::Finder.new(departure, arrival, 4).path
      path.should_not be_blank
      path.size.should == 6
      path[2].physical_road.objectid.should == "ac"
      path[3].physical_road.objectid.should == "cf"
    end  

    it "should find a solution between first and last road with" do
      cf_conditionnal_costs = create(:physical_road_conditionnal_cost, :physical_road => cf, :tags => "bike", :cost => 0.5)
      path = ActiveRoad::ShortestPath::Finder.new(departure, arrival, 4, ["bike"]).path
      path.should_not be_blank
      path.size.should == 7
      path[2].physical_road.objectid.should == "ac"
      path[3].physical_road.objectid.should == "ce"
      path[4].physical_road.objectid.should == "ef"
    end
    
    it "should find a solution between first and last road with context arguments in constraints" do
      cf_conditionnal_costs = create(:physical_road_conditionnal_cost, :physical_road => cf, :tags => "bike", :cost => 0.5)  
      path = ActiveRoad::ShortestPath::Finder.new(departure, arrival, 4, ["~bike"]).path
      path.should_not be_blank
      path.size.should == 7
      path[2].physical_road.objectid.should == "ac"
      path[3].physical_road.objectid.should == "ce"
      path[4].physical_road.objectid.should == "ef"
    end

    it "should return something when no solution" do
      subject = ActiveRoad::ShortestPath::Finder.new departure, arrival, 4, constraints
    end
    
  end

  describe "#path_weights" do       
    
    let(:subject) { ActiveRoad::ShortestPath::Finder.new departure, arrival, 4, ["test"] }
    
    it "should return 0 if no physical road" do
      path = departure 
      subject.path_weights(path).should == 0
    end
    
    it "should return path weight if physical road" do     
      path = ActiveRoad::Path.new(:departure => create(:junction), :physical_road => create(:physical_road) ) 
      path.stub :length_in_meter => 2
      subject.path_weights(path).should == 2 / (4 * 1000/3600)
    end

    it "should return path weights and node weight if nodes have weight" do
      path = ActiveRoad::Path.new(:departure => create(:junction, :waiting_constraint => 2.5), :physical_road => create(:physical_road) )
      path.stub :length_in_meter => 2
      subject.path_weights(path).should == 2 / (4 * 1000/3600) + 2.5
    end

    it "should return path weights and physical roads weight if physical roads have weight" do
      physical_road = create(:physical_road)
      physical_road_conditionnal_cost = create(:physical_road_conditionnal_cost, :physical_road => physical_road, :tags => "test", :cost => 0.2)
      path = ActiveRoad::Path.new(:departure => create(:junction), :physical_road => physical_road )
      path.stub :length_in_meter => 2
      subject.path_weights(path).should == 2 / (4 * 1000/3600) + (2 / (4 * 1000/3600)) * 0.2
    end

  end

  describe "#refresh_context" do
    let(:subject) { ActiveRoad::ShortestPath::Finder.new departure, arrival, 4 }

    it "should increase uphill if path has got a departure with an uphill value" do
      node = ActiveRoad::Path.new( :physical_road => create(:physical_road, :uphill => 3.0), :departure => create(:junction))
      context = {:uphill => 3}
      subject.refresh_context(node, context).should == { :uphill => 6.0, :downhill => 0, :height => 0}      
    end

    it "should not increase uphill if path hasn't' got a departure with an uphill value" do
      node = ActiveRoad::Path.new( :physical_road => create(:physical_road), :departure => create(:junction))
      context = {:uphill => 3}
      subject.refresh_context(node, context).should == { :uphill => 3.0, :downhill => 0, :height => 0}
    end

    it "should set context uphill to 0 if path hasn't' got a departure with an uphill value and no previous context" do 
      node = ActiveRoad::Path.new( :physical_road => create(:physical_road), :departure => create(:junction))
      context = {}
      subject.refresh_context(node, context).should == { :uphill => 0, :downhill => 0, :height => 0}
    end

    it "should return {} if node is not a ActiveRoad::Path" do 
      node = GeoRuby::SimpleFeatures::Point.from_x_y(0, 0)
      context = {}
      subject.refresh_context(node, context).should == {:uphill=>0, :downhill=>0, :height=>0}
    end
  end

  describe "#follow_way" do       
    
    let(:node) { mock(:node) }
    let(:destination) { mock(:destination) }
    let(:weight) { 2 }
    let(:context) { {:uphill => 2} }
    let(:subject) { ActiveRoad::ShortestPath::Finder.new departure, arrival, 4, [], {:uphill => 2} }

    before(:each) do 
      subject.stub :search_heuristic => 1
      subject.stub :time_heuristic => 2      
    end
    
    it "should not follow way if uphill > uphill max" do     
      subject.follow_way_filter = {:uphill => 1}
      subject.follow_way?(node, destination, weight, context).should be_false
    end

    it "should follow way if uphill < uphill max" do
      subject.follow_way_filter = {:uphill => 3}
      subject.follow_way?(node, destination, weight, context).should be_true
    end

  end
  
end
