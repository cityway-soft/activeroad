require 'spec_helper'

describe ActiveRoad::ShortestPath::Finder do

  let!(:first_road) { Factory(:physical_road, :geometry => rgeometry("LINESTRING(0 0, 1 1)") ) }
  let!(:second_road) { Factory(:physical_road, :geometry => rgeometry("LINESTRING(1 1, 2 2)") ) }
  let!(:third_road) { Factory(:physical_road, :geometry => rgeometry("LINESTRING(2 2, 0 3)")) }

  let(:geometry_roads) { rgeometry("LINESTRING(0 0, 1 1, 2 2, 0 3)") }

  let!(:origin) { rgeometry("POINT(0 0)") }
  let!(:destination) { rgeometry("POINT(0 3.05)") }

  let(:first_access_point) { ActiveRoad::AccessPoint.new( {:location => rgeometry("POINT(0 0)"), :physical_road => first_road }) }
  let(:first_access_link) { ActiveRoad::AccessLink.new( {:departure => origin, :arrival => first_access_point} ) }
  
  let!(:first_junction) { Factory(:junction, :geometry => rgeometry("POINT(0 0)"), :physical_roads => [first_road])}
  let!(:second_junction) { Factory(:junction, :geometry => rgeometry("POINT(1 1)"), :physical_roads => [first_road, second_road])}
  let!(:third_junction) { Factory(:junction, :geometry => rgeometry("POINT(2 2)"), :physical_roads => [second_road, third_road])}
  let!(:fourth_junction) { Factory(:junction, :geometry => rgeometry("POINT(0 3)"), :physical_roads => [third_road])}

  subject { ActiveRoad::ShortestPath::Finder.new origin, destination }


  describe "#visited?" do
    it "should return node" do
      subject.visit(origin)
      subject.visited?(origin).should be_true                                                        
    end

    it "should return node arrival" do
      access_link = ActiveRoad::AccessLink.new({:departure => origin, :arrival => destination})
      subject.visit(access_link)
      subject.visited?(access_link).should be_true
    end    
  end

  describe "#visit" do
    it "should return node => true" do
      subject.visit(origin).should be_true                                                 
    end
  end

  describe "#destination_accesses" do
    it "should return AccessPoint" do
      subject.destination_accesses.collect(&:location).should == [destination]
    end
  end

  describe "#search_heuristic" do
    it "should return 8" do
      subject.stub :shortest_distances => {origin => 4}
      subject.search_heuristic(origin).should == 7.05
    end
  end

  describe "#distance_heuristic" do    
    it "should return 4 when node is a point" do
      subject.distance_heuristic(origin).should == 3.05
    end    

    it "should return 4 when node is an access link " do
      subject.distance_heuristic(ActiveRoad::AccessLink.new({:departure => origin, :arrival => origin})).should == 3.05
    end    
  end

  describe "#follow_way" do
    it "should follow the way" do
      subject.stub :search_heuristic => 8
      subject.stub :distance_heuristic => 2
      subject.follow_way?(origin, destination, 2).should be_true
    end

    it "should not follow the way" do
      subject.stub :search_heuristic => 20
      subject.stub :distance_heuristic => 1
      subject.follow_way?(origin, destination, 2).should be_false
    end
  end

  describe "#paths" do
    
    it "should return ActiveRoad::AccessLink when node is a point" do
      ActiveRoad::AccessLink.stub :from => ActiveRoad::AccessLink.from(origin, "road")
      subject.paths(origin).should == ActiveRoad::AccessLink.from(origin, "road")
    end
    
    it "should return ActiveRoad::AccessPoint when node is an AccessLink" do
      paths = subject.paths(first_access_link)
      paths.first.departure.should == first_access_point
      paths.first.physical_road.should == first_road
    end

  end

  describe "#ways" do
    
    # it "should return paths for ways if node is not a RGeo::Geos::FFIPointImpl" do
    #   paths = first_access_link.paths("roads")
    #   subject.stub :paths => paths
    #   subject.ways(first_access_link).should == Hash[paths.first, 0.0]
    # end
    
    # it "should return ActiveRoad::AccessLink when node is a point" do
    #   paths = [first_access_link]
    #   subject.stub :paths => paths
    #   subject.ways(origin).should ==  Hash[paths.first, 1.4142135623731]
    # end

  end

  describe "#geometry" do
    let(:path) { [ mock(:to_geometry => first_road.geometry), mock(:to_geometry => second_road.geometry), mock(:to_geometry => third_road.geometry) ] }

    it "should return a merge of the path" do
      subject.stub :path => path
      subject.geometry.should == geometry_roads
    end
    
  end

  describe "#path" do
    it "should find a solution between first and last road" do
      subject.path.should_not be_blank
    end
  end
  
end
