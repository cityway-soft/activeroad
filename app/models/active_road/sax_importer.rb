class ActiveRoad::SaxImporter

  attr_reader :parser

  def initialize(xml_file)
    @parser = ::Saxerator.parser(File.new(xml_file))
  end

  def import
    parser.for_tag(:LogicalRoad).each do |logical_road|
      LogicalRoadXml.new(logical_road).import
    end 

    parser.for_tag(:PhysicalRoad).each do |physical_road|
      pr = PhysicalRoadXml.new(physical_road).import            
      
      if (pr.present? && physical_road["ConditionnalCost"].present?)
        physical_road["ConditionnalCost"].class != Saxerator::Builder::ArrayElement ? conditionnal_costs = [physical_road["ConditionnalCost"]] : conditionnal_costs = physical_road["ConditionnalCost"] 
        conditionnal_costs.each do |conditionnal_cost|
          PhysicalRoadConditionnalCostXml.new(conditionnal_cost, pr.id).import
        end 
      end
     
    end

    parser.for_tag(:Junction).each do |junction|
      JunctionXml.new(junction).import      
    end

    parser.for_tag(:StreetNumber).each do |street_number|
      StreetNumberXml.new(street_number).import      
    end
    
  end

  class ElementXml
    attr_reader :xml, :parent_id
    
    def initialize(xml, parent_id = nil)
      @xml = xml
      @parent_id = parent_id
    end

    def attributes
      xml.attributes
    end

    def objectid
      attributes['objectid']
    end

    def geometry
      GeoRuby::SimpleFeatures::Geometry.from_ewkt( xml['Geometry'] ) 
    end
    
  end

  class ElementHash
    attr_reader :hash, :parent_id
    
    def initialize(hash, parent_id = nil)      
      @hash = hash
      @parent_id = parent_id
    end      

  end

  class PhysicalRoadConditionnalCostXml < ElementHash   

    def import      
      ActiveRoad::PhysicalRoadConditionnalCost.create(:cost => hash['cost'].to_f, :objectid => hash['objectid'], :tags => hash['tags'], :physical_road_id => parent_id)
    end
    
  end

  class LogicalRoadXml < ElementXml
    
    def name
      xml['Name']
    end   

    def import
      ActiveRoad::LogicalRoad.create(:name => name, :objectid => objectid)
    end
    
  end

  class PhysicalRoadXml < ElementXml
      
    def logical_road
      ActiveRoad::LogicalRoad.find_by_objectid( attributes['logicalRoadRef'] )
    end   

    def kind
      tags =  attributes['tags'].split(",")
      (tags.present? && tags.include?("rail") ) ? "rail" : "road"
    end
   
    def import      
      ActiveRoad::PhysicalRoad.create(:geometry => geometry, :kind => kind, :tags => attributes['tags'], :logical_road_id => logical_road.id, :objectid => objectid) if (geometry && logical_road)
    end
    
  end

  class JunctionXml < ElementXml

    def import
      ActiveRoad::Junction.create(:objectid => objectid, :tags => attributes['tags'], :geometry => geometry)
    end
    
  end

  class JunctionConditionnalCostXml < ElementXml
    
    def start_physical_road_id
      ActiveRoad::PhysicalRoad.find_by_objectid( xml['physicalRoadStartRef'] ).id
    end

    def end_physical_road_id
      ActiveRoad::PhysicalRoad.find_by_objectid( xml['physicalRoadEndRef'] ).id
    end

    def import
      ActiveRoad::JunctionConditionnalCost.create(:cost => attributes['cost'], :objectid => objectid, :tags => attributes['tags'], :start_physical_road_id => start_physical_road_id, :end_physical_road_id => end_physical_road_id, :junction_id => junction_id)
    end
    
  end

  class StreetNumberXml < ElementXml
      # TODO : Fix location_on_road value
    def physical_road 
      ActiveRoad::PhysicalRoad.find_by_objectid( attributes['physicalRoadRef'] )
    end
      
    def import
      ActiveRoad::StreetNumber.create(:number => attributes['number'], :objectid => objectid, :geometry => geometry, :location_on_road => 1, :physical_road_id => physical_road.id)
    end

  end

end
