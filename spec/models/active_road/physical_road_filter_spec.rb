require 'spec_helper'

describe ActiveRoad::PhysicalRoadFilter do

  describe "#sql_request" do
    
    it "should return sql_request with min key" do
      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({"min_size" => "2"})    
      physical_road_filter.sql_request.should == "(tags -> 'size')::int > :min_size AND kind = :kind"
    end

    it "should return sql_request with max key" do
      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({"max_size" => "2"})    
      physical_road_filter.sql_request.should == "(tags -> 'size')::int < :max_size AND kind = :kind"
    end

    it "should return sql_request with default key" do
      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({"pedestrian" => "true"})    
      physical_road_filter.sql_request.should == "tags -> 'pedestrian' = :pedestrian AND kind = :kind"
    end

    it "should return sql_request with 3 parameter" do       
      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({"pedestrian" => "true", "max_size" => "2", "min_size" => "1"})    
      physical_road_filter.sql_request.should == "tags -> 'pedestrian' = :pedestrian AND (tags -> 'size')::int < :max_size AND (tags -> 'size')::int > :min_size AND kind = :kind"
    end

  end

  describe "#sql_arguments" do
    it "should return no arguments if no tags and no kind" do
      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new
      physical_road_filter.sql_arguments.should == {:kind => "road"}
    end

    it "should return arguments if tags" do
      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({:test => "ab"})
      physical_road_filter.sql_arguments.should == {:test => "ab", :kind => "road"}
    end

  end

  describe "#filter" do
       
    it "should return physical roads which contains  arguments" do
      physical_road = create(:physical_road, :tags => {:test => "ab", :size => "3"})
      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({:test => "ab", :min_size => "2", :max_size => "4"})
      physical_road_filter.filter.should == [physical_road]
    end

    it "should return no physical roads" do
      physical_road = create(:physical_road, :tags => {:test => "ab"})
      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({:test => "a"})
      physical_road_filter.filter.should == []      
    end

    it "should return all physical roads with the default kind" do
      physical_road = create(:physical_road)
      physical_road2 = create(:physical_road, :tags => {:test => "ab", :size => "3"})

      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new()
      physical_road_filter.filter.should =~ [physical_road, physical_road2]      

      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({}, "road")
      physical_road_filter.filter.should =~ [physical_road, physical_road2]      

      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({}, "road")
      physical_road_filter.filter.should =~ [physical_road, physical_road2]      
    end
    
  end

end
