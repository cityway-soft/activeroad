require 'spec_helper'

describe ActiveRoad::ShortestPathFinder do

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
    let!(:a) { create(:junction, :objectid => "a", :geometry => ActiveRoad::RgeoExt.cartesian_factory.point(0.0, 0.0) ) }
    let!(:b) { create(:junction, :objectid => "b", :geometry => ActiveRoad::RgeoExt.cartesian_factory.point(1.0, 0.0) ) }
    let!(:c) { create(:junction, :objectid => "c", :geometry => ActiveRoad::RgeoExt.cartesian_factory.point(0.0, 1.0) ) }
    let!(:d) { create(:junction, :objectid => "d", :geometry => ActiveRoad::RgeoExt.cartesian_factory.point(1.0, 1.0) ) }
    let!(:e) { create(:junction, :objectid => "e", :geometry => ActiveRoad::RgeoExt.cartesian_factory.point(0.0, 2.0) ) }
    let!(:f) { create(:junction, :objectid => "f", :geometry => ActiveRoad::RgeoExt.cartesian_factory.point(1.0, 2.0) ) }    
    
    let!(:ab) { create(:physical_road, :objectid => "ab", :geometry => ActiveRoad::RgeoExt.cartesian_factory.line_string([a.geometry, b.geometry]) ) }
    let!(:cd) { create(:physical_road, :objectid => "cd", :geometry => ActiveRoad::RgeoExt.cartesian_factory.line_string([c.geometry, d.geometry]) ) }
    let!(:ef) { create(:physical_road, :objectid => "ef", :geometry => ActiveRoad::RgeoExt.cartesian_factory.line_string([e.geometry, f.geometry]) ) }
    let!(:ac) { create(:physical_road, :objectid => "ac", :geometry => ActiveRoad::RgeoExt.cartesian_factory.line_string([a.geometry, c.geometry]) ) }
    let!(:bd) { create(:physical_road, :objectid => "bd", :geometry => ActiveRoad::RgeoExt.cartesian_factory.line_string([b.geometry, d.geometry]), :transport_mode => "bike" ) }
    let!(:ce) { create(:physical_road, :objectid => "ce", :geometry => ActiveRoad::RgeoExt.cartesian_factory.line_string([c.geometry, e.geometry]) ) }
    let!(:df) { create(:physical_road, :objectid => "df", :geometry => ActiveRoad::RgeoExt.cartesian_factory.line_string([d.geometry, f.geometry]), :transport_mode => "bike" ) }
    let!(:cf) { create(:physical_road, :objectid => "cf", :geometry => ActiveRoad::RgeoExt.cartesian_factory.line_string([c.geometry, f.geometry]), :transport_mode => "bike" ) }

    before :each do 
      a.physical_roads << [ ab, ac ]
      b.physical_roads << [ ab, bd ]
      c.physical_roads << [ cd, ac, ce, cf ]
      d.physical_roads << [ cd, bd, df ]
      e.physical_roads << [ ce, ef ]
      f.physical_roads << [ ef, df, cf ]
    end
    
  end
  
  let(:departure) { ActiveRoad::RgeoExt.cartesian_factory.point(-0.0005, 0.0005) }
  let(:arrival) { ActiveRoad::RgeoExt.cartesian_factory.point(1.0005, 2.0005) }
  let(:speed) { 4 }
  let(:constraints) { ["bike"] }

  describe "#path" do       
    include_context "shared simple graph"
    
    it "should find a solution between first and last road with with no constraints" do
      path = ActiveRoad::ShortestPathFinder.new(departure, arrival, 4).path
      expect(path.size).to eq(6)
      expect(path[0]).to eq(departure)
      expect(path[1].class).to eq(ActiveRoad::AccessLink)
      expect(path[2].physical_road.objectid).to eq("ac")
      expect(path[3].physical_road.objectid).to eq("cf")
      expect(path[4].class).to eq(ActiveRoad::AccessLink)
      expect(path[5]).to eq(arrival)
    end  

    it "should find a solution between first and last road with constraints" do
      path = ActiveRoad::ShortestPathFinder.new(departure, arrival, 4, {"transport_mode" => "bike"}).path
      expect(path.size).to eq(6)
      expect(path[0]).to eq(departure)
      expect(path[1].class).to eq(ActiveRoad::AccessLink)
      expect(path[2].physical_road.objectid).to eq("ac")
      expect(path[3].physical_road.objectid).to eq("cf")
      expect(path[4].class).to eq(ActiveRoad::AccessLink)
      expect(path[5]).to eq(arrival)
    end
    
    it "should find a solution between first and last road with constraints which block the itinerary" do
      path = ActiveRoad::ShortestPathFinder.new(departure, arrival, 4, { "transport_mode" => "~bike"}).path
      expect(path.size).to eq(7)
      expect(path[0]).to eq(departure)
      expect(path[1].class).to eq(ActiveRoad::AccessLink)
      expect(path[2].physical_road.objectid).to eq("ac")
      expect(path[3].physical_road.objectid).to eq("ce")
      expect(path[4].physical_road.objectid).to eq("ef")
      expect(path[5].class).to eq(ActiveRoad::AccessLink)
      expect(path[6]).to eq(arrival)
    end

    it "should return something when no solution" do
      departure = ActiveRoad::RgeoExt.cartesian_factory.point(-0.01, 0.01)
      path = ActiveRoad::ShortestPathFinder.new(departure, arrival, 4).path
      expect(path).to eq([])      
    end

    it "should return something when departure or arrival are 'outside the graph'" do
      departure = ActiveRoad::RgeoExt.cartesian_factory.point(-0.0005, -0.0005)
      path = ActiveRoad::ShortestPathFinder.new(departure, arrival, 4).path

      expect(path.size).to eq(6)
      expect(path[0]).to eq(departure)
      expect(path[1].class).to eq(ActiveRoad::AccessLink)
      expect(path[2].physical_road.objectid).to eq("ac")
      expect(path[3].physical_road.objectid).to eq("cf")
      expect(path[4].class).to eq(ActiveRoad::AccessLink)
      expect(path[5]).to eq(arrival)
    end
    
  end

  describe "#path_weights" do       
    
    let(:subject) { ActiveRoad::ShortestPathFinder.new departure, arrival, 4, { :transport_mode => "~bike" } }
    
    it "should return 0 if no physical road" do
      path = departure 
      expect(subject.path_weights(path)).to eq(0)
    end
    
    it "should return path weight if physical road" do
      path = ActiveRoad::Path.new(:departure => create(:junction), :physical_road => create(:physical_road) ) 
      
      allow(path).to receive_messages :length => 2
      expect(subject.path_weights(path)).to eq(2 / (4 * 1000/3600))
    end

    it "should return path weights and node weight if nodes have weight" do
      path = ActiveRoad::Path.new(:departure => create(:junction, :waiting_constraint => 2.5), :physical_road => create(:physical_road) )
      
      allow(path).to receive_messages :length => 2
      expect(subject.path_weights(path)).to eq(2 / (4 * 1000/3600) + 2.5)
    end

    it "should return path weights == Infinity and physical roads weight if physical roads have weight" do
      physical_road = create(:physical_road, :transport_mode => "bike")
      path = ActiveRoad::Path.new(:departure => create(:junction), :physical_road => physical_road )
      
      allow(path).to receive_messages :length => 2
      expect(subject.path_weights(path)).to eq(Float::INFINITY)
    end

  end

  describe "#refresh_context" do
    let(:subject) { ActiveRoad::ShortestPathFinder.new departure, arrival, 4 }

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
      node = ActiveRoad::RgeoExt.cartesian_factory.point(0, 0)
      context = {}
      expect(subject.refresh_context(node, context)).to eq({:uphill=>0, :downhill=>0, :height=>0})
    end
  end

  describe "#follow_way" do       
    
    let(:node) { double(:node) }
    let(:destination) { double(:destination) }
    let(:context) { {:uphill => 2} }
    let(:subject) { ActiveRoad::ShortestPathFinder.new departure, arrival, 4, [], {:uphill => 2} }

    before(:each) do 
      allow(subject).to receive_messages :search_heuristic => 1
      allow(subject).to receive_messages :time_heuristic => 2      
    end
    
    it "should not follow way if weight == Infinity" do      
      expect(subject.follow_way?(node, destination, Float::INFINITY)).to be_falsey
    end

    it "should not follow way if uphill > uphill max" do     
      subject.thresholds = {:uphill => 1}
      expect(subject.follow_way?(node, destination, 2, context)).to be_falsey
    end

    it "should follow way if uphill < uphill max" do
      subject.thresholds = {:uphill => 3}
      expect(subject.follow_way?(node, destination, 2, context)).to be_truthy
    end

  end

  describe "#geometry" do         
    include_context "shared simple graph"
    
    let(:shortest_path) { ActiveRoad::ShortestPathFinder.new(departure, arrival, 4) }

    it "should return geometry" do
      expect(shortest_path.geometry.as_text).to eq( "SRID=4326;LineString (-0.0005 0.0005, 0.0 0.0005, 0.0 0.0005, 0.0 1.0, 0.0 1.0, 1.0 2.0, 1.0 2.0, 1.0 1.98, 1.0 1.98, 1.0005 1.98)" )
    end
  end
  
end

