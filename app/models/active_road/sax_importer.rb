class ActiveRoad::SaxImporter

  attr_reader :parser

  def initialize(xml_file)
    @parser = ::Saxerator.parser(File.new(xml_file))
  end

  def import
    parser.for_tag(:LogicalRoad).each do |logical_road|
      logical_road_attributes = logical_road.attributes
      ActiveRoad::LogicalRoad.create :name => logical_road['Name'], :objectid => logical_road_attributes['objectid']
    end 

    parser.for_tag(:PhysicalRoad).each do |physical_road|
      physical_road_attributes = physical_road.attributes
      geometry = GeoRuby::SimpleFeatures::Geometry.from_ewkt( physical_road['Geometry'] ) 
      tags =  physical_road_attributes['tags'].split(",")
      kind = (tags.present? && tags.include?("rail") ) ? "rail" : "road"
      logical_road = ActiveRoad::LogicalRoad.find_by_objectid( physical_road_attributes['logicalRoadRef'] )
      ActiveRoad::PhysicalRoad.create(:geometry => geometry, :kind => kind, tags => physical_road_attributes['tags'], :logical_road_id => logical_road.id, :objectid => physical_road_attributes['objectid']) if (geometry && logical_road)
    end

    parser.for_tag(:Junction).each do |junction|
      junction_attributes = junction.attributes
      ActiveRoad::Junction.create :objectid => junction_attributes['objectid'], :tags => junction_attributes['tags'], :geometry => junction['Geometry']
    end

    parser.for_tag(:StreetNumber).each do |street_number|
      street_number_attributes = street_number.attributes
      geometry = GeoRuby::SimpleFeatures::Geometry.from_ewkt( street_number['Geometry'] ) 
      # TODO : Fix location_on_road value
      physical_road = ActiveRoad::PhysicalRoad.find_by_objectid( street_number_attributes['physicalRoadRef'] )
      puts ActiveRoad::StreetNumber.create(:number => street_number_attributes['number'], :objectid => street_number_attributes['objectid'], :geometry => geometry, :location_on_road => 1, :physical_road_id => physical_road.id).errors.inspect
    end
    
  end


  def import_logical_road
  end

 
end
