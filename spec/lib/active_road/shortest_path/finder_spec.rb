require 'spec_helper'

describe ActiveRoad::ShortestPath::Finder do

  shared_context "shared simple graph" do
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
    let!(:ab) { create(:physical_road, :objectid => "ab", :geometry => line_string( "0.0 0.0,1.0 0.0" ) ) }
    let!(:cd) { create(:physical_road, :objectid => "cd", :geometry => line_string( "0.0 1.0,1.0 1.0" ) ) }
    let!(:ef) { create(:physical_road, :objectid => "ef", :geometry => line_string( "0.0 2.0,1.0 2.0" ) ) }
    let!(:ac) { create(:physical_road, :objectid => "ac", :geometry => line_string( "0.0 0.0,0.0 1.0" ) ) }
    let!(:bd) { create(:physical_road, :objectid => "bd", :geometry => line_string( "1.0 0.0,1.0 1.0" ) ) }
    let!(:ce) { create(:physical_road, :objectid => "ce", :geometry => line_string( "0.0 1.0,0.0 2.0" ) ) }
    let!(:df) { create(:physical_road, :objectid => "df", :geometry => line_string( "1.0 1.0,1.0 2.0" ) ) }
    let!(:cf) { create(:physical_road, :objectid => "cf", :geometry => line_string( "0.0 1.0,1.0 2.0" ) ) }

    let!(:a) { create(:junction, :objectid => "a", :geometry => point(0.0, 0.0), :physical_roads => [ ab, ac ] ) }
    let!(:b) { create(:junction, :objectid => "b", :geometry => point(1.0, 0.0), :physical_roads => [ ab, bd ] ) }
    let!(:c) { create(:junction, :objectid => "c", :geometry => point(0.0, 1.0), :physical_roads => [ cd, ac, ce, cf ] ) }
    let!(:d) { create(:junction, :objectid => "d", :geometry => point(1.0, 1.0), :physical_roads => [ cd, bd, df ] ) }
    let!(:e) { create(:junction, :objectid => "e", :geometry => point(0.0, 2.0), :physical_roads => [ ce, ef ] ) }
    let!(:f) { create(:junction, :objectid => "f", :geometry => point(1.0, 2.0), :physical_roads => [ ef, df, cf ] ) }
    
  end
  
  let(:departure) { point(-0.0005, 0.0005) }
  let(:arrival) { point(1.0005, 1.98) }
  let(:speed) { 4 }
  let(:constraints) { ["bike"] }

  describe "#path" do       
    include_context "shared simple graph"
    
    it "should find a solution between first and last road with with no constraints" do
      path = ActiveRoad::ShortestPath::Finder.new(departure, arrival, 4).path
      expect(path.size).to eq(7)
      expect(path[0]).to eq(departure)
      expect(path[1].class).to eq(ActiveRoad::AccessLink)
      expect(path[2].physical_road.objectid).to eq("ac")
      expect(path[3].physical_road.objectid).to eq("cf")
      expect(path[4].physical_road.objectid).to eq("df")
      expect(path[5].class).to eq(ActiveRoad::AccessLink)
      expect(path[6]).to eq(arrival)
    end  

    it "should find a solution between first and last road with constraints" do
      cf_conditionnal_costs = create(:physical_road_conditionnal_cost, :physical_road => cf, :tags => "bike", :cost => 0.7)
      path = ActiveRoad::ShortestPath::Finder.new(departure, arrival, 4, ["bike"]).path
      expect(path.size).to eq(7)
      expect(path[0]).to eq(departure)
      expect(path[1].class).to eq(ActiveRoad::AccessLink)
      expect(path[2].physical_road.objectid).to eq("ac")
      expect(path[3].physical_road.objectid).to eq("cd")
      expect(path[4].physical_road.objectid).to eq("df")
      expect(path[5].class).to eq(ActiveRoad::AccessLink)
      expect(path[6]).to eq(arrival)
    end
    
    it "should find a solution between first and last road with constraints which block the itinerary" do
      cf_conditionnal_costs = create(:physical_road_conditionnal_cost, :physical_road => cf, :tags => "bike", :cost => 0)  
      path = ActiveRoad::ShortestPath::Finder.new(departure, arrival, 4, ["~bike"]).path
      expect(path.size).to eq(7)
      expect(path[0]).to eq(departure)
      expect(path[1].class).to eq(ActiveRoad::AccessLink)
      expect(path[2].physical_road.objectid).to eq("ac")
      expect(path[3].physical_road.objectid).to eq("cd")
      expect(path[4].physical_road.objectid).to eq("df")
      expect(path[5].class).to eq(ActiveRoad::AccessLink)
      expect(path[6]).to eq(arrival)
    end

    it "should return something when no solution" do
      departure = point(-0.01, 0.01)
      path = ActiveRoad::ShortestPath::Finder.new(departure, arrival, 4).path
      expect(path).to eq([])      
    end

    it "should return something when departure or arrival are 'outside the graph'" do
      departure = point(-0.0005, -0.0005)
      path = ActiveRoad::ShortestPath::Finder.new(departure, arrival, 4).path
      expect(path.size).to eq(7)
      expect(path[0]).to eq(departure)
      expect(path[1].class).to eq(ActiveRoad::AccessLink)
      expect(path[2].physical_road.objectid).to eq("ac")
      expect(path[3].physical_road.objectid).to eq("cf")
      expect(path[4].physical_road.objectid).to eq("df")
      expect(path[5].class).to eq(ActiveRoad::AccessLink)
      expect(path[6]).to eq(arrival)
    end
    
  end

  describe "#path_weights" do       
    
    let(:subject) { ActiveRoad::ShortestPath::Finder.new departure, arrival, 4, ["test"] }
    
    it "should return 0 if no physical road" do
      path = departure 
      expect(subject.path_weights(path)).to eq(0)
    end
    
    it "should return path weight if physical road" do
      path = ActiveRoad::Path.new(:departure => create(:junction), :physical_road => create(:physical_road) ) 
      allow(path).to receive_messages :length_in_meter => 2
      expect(subject.path_weights(path)).to eq(2 / (4 * 1000/3600))
    end

    it "should return path weights and node weight if nodes have weight" do
      path = ActiveRoad::Path.new(:departure => create(:junction, :waiting_constraint => 2.5), :physical_road => create(:physical_road) )
      allow(path).to receive_messages :length_in_meter => 2
      expect(subject.path_weights(path)).to eq(2 / (4 * 1000/3600) + 2.5)
    end

    it "should return path weights and physical roads weight if physical roads have weight" do
      physical_road = create(:physical_road)
      physical_road_conditionnal_cost = create(:physical_road_conditionnal_cost, :physical_road => physical_road, :tags => "test", :cost => 0.2)
      path = ActiveRoad::Path.new(:departure => create(:junction), :physical_road => physical_road )
      allow(path).to receive_messages :length_in_meter => 2
      expect(subject.path_weights(path)).to eq(2 / (4 * 1000/3600) + (2 / (4 * 1000/3600)) * 0.2)
    end

    it "should return path weights == Infinity and physical roads weight if physical roads have weight" do
      physical_road = create(:physical_road)
      physical_road_conditionnal_cost = create(:physical_road_conditionnal_cost, :physical_road => physical_road, :tags => "test", :cost => Float::MAX)
      path = ActiveRoad::Path.new(:departure => create(:junction), :physical_road => physical_road )
      allow(path).to receive_messages :length_in_meter => 2
      expect(subject.path_weights(path)).to eq(Float::INFINITY)
    end

  end

  describe "#refresh_context" do
    let(:subject) { ActiveRoad::ShortestPath::Finder.new departure, arrival, 4 }

    it "should increase uphill if path has got a departure with an uphill value" do
      node = ActiveRoad::Path.new( :physical_road => create(:physical_road, :uphill => 3.0), :departure => create(:junction))
      context = {:uphill => 3}
      expect(subject.refresh_context(node, context)).to eq({ :uphill => 6.0, :downhill => 0, :height => 0})      
    end

    it "should not increase uphill if path hasn't' got a departure with an uphill value" do
      node = ActiveRoad::Path.new( :physical_road => create(:physical_road), :departure => create(:junction))
      context = {:uphill => 3}
      expect(subject.refresh_context(node, context)).to eq({ :uphill => 3.0, :downhill => 0, :height => 0})
    end

    it "should set context uphill to 0 if path hasn't' got a departure with an uphill value and no previous context" do 
      node = ActiveRoad::Path.new( :physical_road => create(:physical_road), :departure => create(:junction))
      context = {}
      expect(subject.refresh_context(node, context)).to eq({ :uphill => 0, :downhill => 0, :height => 0})
    end

    it "should return {} if node is not a ActiveRoad::Path" do 
      node = GeoRuby::SimpleFeatures::Point.from_x_y(0, 0)
      context = {}
      expect(subject.refresh_context(node, context)).to eq({:uphill=>0, :downhill=>0, :height=>0})
    end
  end

  describe "#follow_way" do       
    
    let(:node) { double(:node) }
    let(:destination) { double(:destination) }
    let(:context) { {:uphill => 2} }
    let(:subject) { ActiveRoad::ShortestPath::Finder.new departure, arrival, 4, [], {:uphill => 2} }

    before(:each) do 
      allow(subject).to receive_messages :search_heuristic => 1
      allow(subject).to receive_messages :time_heuristic => 2      
    end
    
    it "should not follow way if weight == Infinity" do      
      expect(subject.follow_way?(node, destination, Float::INFINITY)).to be_falsey
    end

    it "should not follow way if uphill > uphill max" do     
      subject.follow_way_filter = {:uphill => 1}
      expect(subject.follow_way?(node, destination, 2, context)).to be_falsey
    end

    it "should follow way if uphill < uphill max" do
      subject.follow_way_filter = {:uphill => 3}
      expect(subject.follow_way?(node, destination, 2, context)).to be_truthy
    end

  end

  describe "#geometry" do         
    include_context "shared simple graph"
    
    let(:shortest_path) { ActiveRoad::ShortestPath::Finder.new(departure, arrival, 4) }

    it "should return geometry" do
      expect(shortest_path.geometry).not_to eq(nil)
    end
  end
  
end

