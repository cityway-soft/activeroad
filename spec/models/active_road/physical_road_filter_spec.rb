require 'spec_helper'

describe ActiveRoad::PhysicalRoadFilter do

  # describe "#sql_request" do
    
  #   it "should return sql_request with min key" do
  #     physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({"min_size" => "2"})    
  #     physical_road_filter.sql_request.should == "(tags -> 'size')::int > :min_size"
  #   end

  #   it "should return sql_request with max key" do
  #     physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({"max_size" => "2"})    
  #     physical_road_filter.sql_request.should == "(tags -> 'size')::int < :max_size"
  #   end

  #   it "should return sql_request with default key" do
  #     physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({"pedestrian" => "true"})    
  #     physical_road_filter.sql_request.should == "tags -> 'pedestrian' != :pedestrian"
  #   end

  #   it "should return sql_request with 3 parameter" do       
  #     physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({"pedestrian" => "true", "max_size" => "2", "min_size" => "1"})    
  #     physical_road_filter.sql_request.should == "tags -> 'pedestrian' != :pedestrian AND (tags -> 'size')::int < :max_size AND (tags -> 'size')::int > :min_size"
  #   end

  # end

  describe "#filter" do
    
    let!( :physical_road )  { create( :physical_road ) }
    let!( :physical_road2 ) { create( :physical_road ) } 
    let!( :physical_road3 ) { create( :physical_road ) }     
       
    it "should return physical roads which contains minimum_width <= narrow" do
      physical_road.update_attribute :minimum_width, :wide
      physical_road2.update_attribute :minimum_width, :cramped

      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({:minimum_width => [:wide, :enlarged, :narrow]})
      physical_road_filter.filter.should =~ [physical_road, physical_road3]      
    end

    it "should return physical roads which contains slope <= medium" do
      physical_road.update_attribute :slope, :medium
      physical_road2.update_attribute :slope, :steep

      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({:slope => [:flat, :medium] })
      physical_road_filter.filter.should =~ [physical_road, physical_road3]      
    end

    it "should return physical roads which contains cant <=  medium" do
      physical_road.update_attribute :cant, :medium
      physical_road2.update_attribute :cant, :steep

      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({:cant => [:flat, :medium] })
      physical_road_filter.filter.should =~ [physical_road, physical_road3]      
    end

    it "should return physical roads which contains physical_road_type == path_link" do
      physical_road.update_attribute :physical_road_type, :path_link
      physical_road2.update_attribute :physical_road_type, :crossing

      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({:physical_road_type => :path_link})
      physical_road_filter.filter.should =~ [physical_road, physical_road3]      

    end

    it "should return physical roads which contains transport_mode == pedestrian" do
      physical_road.update_attribute :transport_mode, :pedestrian
      physical_road2.update_attribute :transport_mode, :bike
      
      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({:transport_mode => [:pedestrian, nil]})
      physical_road_filter.filter.should =~ [physical_road, physical_road3]            
    end

    it "should return physical roads which contains covering == asphalt_road or pavement" do
      physical_road.update_attribute :covering, :asphalt_road
      physical_road2.update_attribute :covering, :pavement
     
      physical_road_filter = ActiveRoad::PhysicalRoadFilter.new({:covering => [:pavement, :asphalt_road, nil]})
      physical_road_filter.filter.should =~ [physical_road, physical_road2, physical_road3]      
    end
  end

end
