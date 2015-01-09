require 'spec_helper'

#####################################
#    More complex path schema       #
#####################################
describe "performance finder test" do       
  let!(:from) { point(0, 0) }
  let!(:to) { point(0.3, 0.3) }    
  let(:subject) { ActiveRoad::ShortestPathFinder.new from, to, 4, [] }
  let(:graph_size) { 0.3 }
  let(:increment_coordinates) { 0.01 }
  let(:round_coordinates) { 2 }
  let(:graph_size_by_unit) { graph_size / increment_coordinates}

  before(:each) do
    x = y = 0.0
    while y <= graph_size
      departure = create(:junction, :objectid => "#{x},#{y}", :geometry => point(x, y) )      

      if y > 0
        previous_departure = ActiveRoad::Junction.find_by_objectid("#{x},#{(y - increment_coordinates).round(round_coordinates)}")
        create(:physical_road, :objectid => "#{x},#{(y - increment_coordinates).round(round_coordinates)}-#{x},#{y}", :geometry => line_string( previous_departure.geometry, departure.geometry ), :junctions => [previous_departure, departure] )
      end      

      while x < graph_size
        x = (x + increment_coordinates).round(round_coordinates)
        arrival = create(:junction, :objectid => "#{x},#{y}", :geometry => point(x, y) )
        create(:physical_road, :objectid => "#{(x - increment_coordinates).round(round_coordinates)},#{y}-#{x},#{y}", :geometry => line_string( departure.geometry, arrival.geometry ), :junctions => [departure, arrival] )

        # Link to previous junctions
        if y > 0          
          previous_arrival = ActiveRoad::Junction.find_by_objectid("#{x},#{(y - increment_coordinates).round(round_coordinates)}")
          create(:physical_road, :objectid => "#{x},#{(y - increment_coordinates).round(round_coordinates)}-#{x},#{y}", :geometry => line_string( previous_arrival.geometry, arrival.geometry ), :junctions => [departure, arrival] )
        end

        # Change the departure in arrival
        departure = arrival
      end  
      
      x = 0.0
      y = (y + increment_coordinates).round(round_coordinates)
    end
  end   
  
  # it "should create correct number of objects", :profile => true do   
  #   ActiveRoad::Junction.all.size.should ==  (graph_size_by_unit + 1 ) * (graph_size_by_unit + 1)
  #   ActiveRoad::PhysicalRoad.all.size.should == graph_size_by_unit * ( 2 * graph_size_by_unit + 2)
  # end

  # Test to read nodes in picardie.osm.pbf data in less 34.910999522 seconds
  # Test to read nodes and create objects in picardie.osm.pbf data in less 190.617743468 seconds
  # Test to write nodes in picardie.osm.pbf data in less  seconds
  # Grille 30 * 30
  # 961 junctions
  # 1802 physical_roads
  
  it "should evaluate path and profile it", :profile => true do
    result = ::RubyProf.profile {      
      expect(subject.path.count).to eq(graph_size_by_unit * 2 + 4)
    }
    puts "subject.path #{subject.path.inspect}"
    # Print a graph profile to text
    open("tmp/performance/callgrind.profile", "w") do |f|
      ::RubyProf::CallTreePrinter.new(result).print(f, :min_percent => 1)
    end
  end

end
