class ActiveRoad::SaxImporter

  attr_reader :parser

  def initialize(xml_file)
    @parser = ::Saxerator.parser(File.new(xml_file))
  end

  def import
    parser.for_tag(:LogicalRoad).each do |logical_road|
      LogicalRoadXml.new(logical_road).import
    end 

    parser.for_tag(:TrajectoryArc).each do |physical_road|
      TrajectoryArcXml.new(physical_road).import      
    end

    parser.for_tag(:TrajectoryNode).each do |junction|
      TrajectoryNodeXml.new(junction).import      
    end

    parser.for_tag(:StreetNumber).each do |street_number|
      StreetNumberXml.new(street_number).import      
    end
    
  end

  class ElementXml
    attr_reader :xml
    
    def initialize(xml)
      @xml = xml
    end

    def objectid
      xml['ObjectId']
    end

    def geometry
      GeoRuby::SimpleFeatures::Geometry.from_ewkt( xml['Geometry'] ) 
    end
    
  end

  class LogicalRoadXml < ElementXml
    
    def name
      xml['Name']
    end   

    def import
      ActiveRoad::LogicalRoad.create :name => name, :objectid => objectid
    end
    
  end

  class TrajectoryArcXml < ElementXml
      
    def logical_road
      ActiveRoad::LogicalRoad.find_by_objectid( logical_road_id )
    end   

    def logical_road_id
      xml['LogicalRoadRef']
    end

    def minimum_width
      xml['MinimumWidth']
    end

    def length
      xml['Length']
    end

    def kind
      tags_array =  xml['Tags'].to_s.split(",")
      (tags_array.present? && tags_array.include?("rail") ) ? "rail" : "road"
    end

    def tags
      xml['Tags'].to_s
    end
    
    def import
      ActiveRoad::PhysicalRoad.create(:geometry => geometry, :kind => kind, :tags => tags, :logical_road_id => logical_road_id, :objectid => objectid, :minimum_with => minimum_width, :length => length) if (geometry) #&& logical_road)
    end
    
  end

  class TrajectoryNodeXml < ElementXml
    
    def tags
      xml['Tags'].to_s
    end

    # def height
    #   xml['Height'] || 0
    # end

    # def physical_road 
    #   ActiveRoad::PhysicalRoad.find_by_objectid( physical_road_id )
    # end

    # def physical_road_id
    #   xml['PhysicalRoadRef']
    # end    

    def physical_roads
      physical_roads = []
      xml['TrajectoryArcRef'].each do |trajectory_arc_ref|
        physical_road = ActiveRoad::PhysicalRoad.find_by_objectid( trajectory_arc_ref.to_s )
        physical_roads << physical_road if physical_road.present?        
      end
      physical_roads
    end 

    def import
      junction = ActiveRoad::Junction.create :objectid => objectid, :tags => tags, :geometry => geometry
      junction.physical_roads << physical_roads
    end
    
  end

  class StreetNumberXml < ElementXml
      # TODO : Fix location_on_road value
    def physical_road 
      ActiveRoad::PhysicalRoad.find_by_objectid( physical_road_ref )
    end

    def physical_road_ref
      xml['TrajectoryArcRef']
    end

    def number
      xml['Number']
    end

    def location_on_road
      xml['LocationOnRoad'] || 0
    end
      
    def import
      ActiveRoad::StreetNumber.create(:number => number , :objectid => objectid, :geometry => geometry, :location_on_road => location_on_road)#, :physical_road_id => physical_road.id)
    end

  end

end
