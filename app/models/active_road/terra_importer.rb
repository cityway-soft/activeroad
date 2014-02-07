# require "kyotocabinet"

# module ActiveRoad
#   class TerraImporter
#     #include KyotoCabinet
    
#     attr_reader :parser, :database_path, :xml_file 

#     def initialize(xml_file, database_path = "/tmp/terra.kch")
#       @xml_file = xml_file
#       @database_path = database_path
#     end

#     def parser
#       @parser ||= ::Saxerator.parser(File.new(xml_file))
#     end   

#     def database
#       @database ||= DB::new
#     end
    
#     def open_database(path)
#       database.open(path, DB::OWRITER | DB::OCREATE)
#       database.clear
#     end
    
#     def close_database
#       database.close   
#     end

#     def physical_road_conditionnal_costs(tags)
#       [].tap do |prcc|
#         tags.each do |tag_key, tag_value|
#           if ["highway", "railway"].include?(tag_key)
#             prcc << ActiveRoad::PhysicalRoadConditionnalCost.new(:tags => "car", :cost => Float::MAX) if !ActiveRoad::OsmXmlImporter.tag_for_car_values.include?(tag_value)  
#             prcc << ActiveRoad::PhysicalRoadConditionnalCost.new(:tags => "pedestrian", :cost => Float::MAX) if !ActiveRoad::OsmXmlImporter.tag_for_pedestrian_values.include?(tag_value)
#             prcc << ActiveRoad::PhysicalRoadConditionnalCost.new(:tags => "bike", :cost => Float::MAX) if !ActiveRoad::OsmXmlImporter.tag_for_bike_values.include?(tag_value) 
#             prcc << ActiveRoad::PhysicalRoadConditionnalCost.new(:tags => "train", :cost => Float::MAX) if !ActiveRoad::OsmXmlImporter.tag_for_train_values.include?(tag_value)
#           end
#         end
#       end
#     end

#     def backup_nodes(database)
#       # Save nodes in kyotocabinet database
#       parser.for_tag(:TrajectoryNode).each do |node|
#         ways = node["TrajectoryArcRef"].is_a?(Array) ? node["TrajectoryArcRef"] : [ node["TrajectoryArcRef"] ]
#         database[ node["ObjectId"] ] = Marshal.dump(Node.new(node["ObjectId"], node["Geometry"], ways))
#       end 
#     end
    
#     def iterate_nodes(database)
#       junctions_values = []    
#       junctions_ways = {}
#       # traverse records by iterator
#       database.each { |key, value|
        
#         node = Marshal.load(value)
#         geometry = GeoRuby::SimpleFeatures::Geometry.from_ewkt( node.geometry) if( node.geometry )    
#         if node.ways.present? # && node.ways.count >= 2  # Take node with at least two ways
#           junctions_values << [ node.id, geometry ]
#           junctions_ways[node.id] = node.ways
#         end
        
#         if junctions_values.count == 1000
#           save_junctions(junctions_values, junction_ways) 
#           #Reset
#           junctions_values = []    
#           junctions_ways = {}
#         end
#       }    
#       save_junctions(junctions_values, junctions_ways) if junctions_values.present?
#     end

#     def save_junctions(junctions_values, junctions_ways)
#       junction_columns = [:objectid, :geometry]
#       # Save junctions in the stack
#       ActiveRoad::Junction.import(junction_columns, junctions_values, :validate => false) if junctions_values.present?

#       # Link the junction with physical roads
#       junctions_ways.each do |junction_objectid, way_objectids|
#         junction = ActiveRoad::Junction.find_by_objectid(junction_objectid)
        
#         physical_roads = ActiveRoad::PhysicalRoad.find_all_by_objectid(way_objectids)
#         junction.physical_roads << physical_roads if physical_roads      
#       end
#     end

#     def import
#       # process the database by iterator
#       DB::process(database_path) { |database|           
#         database.clear
#         backup_nodes(database)

#         physical_roads = []
#         attributes_by_objectid = {}
#         parser.for_tag(:TrajectoryArc).each do |way|          
#           geometry = GeoRuby::SimpleFeatures::Geometry.from_ewkt(way["Geometry"]) if way["Geometry"]
#           physical_road = ActiveRoad::PhysicalRoad.new :objectid =>  way["ObjectId"], :geometry => geometry, :length_in_meter =>  way["Length"]
          
#           physical_roads << physical_road
#           attributes_by_objectid[physical_road.objectid] = [physical_road_conditionnal_costs(way["Tags"])]

#           if (physical_roads.count == 1000)
#             save_physical_roads_and_children(physical_roads, attributes_by_objectid)
            
#             # Reset  
#             physical_roads = []
#             attributes_by_objectid = {}
#           end
#         end
        
#         save_physical_roads_and_children(physical_roads, attributes_by_objectid) if physical_roads.present?
#         iterate_nodes(database)
#       }
#     end

#    def save_physical_roads_and_children(physical_roads, attributes_by_objectid = {})
#       # Save physical roads
#       ActiveRoad::PhysicalRoad.import(physical_roads)

#       # Save physical road conditionnal costs
#       prcc = []
#       attributes_by_objectid.each do |objectid, attributes|
#         pr = ActiveRoad::PhysicalRoad.where(:objectid => objectid).first

#         physical_road_conditionnal_costs = attributes.first
#         physical_road_conditionnal_costs.each do |physical_road_conditionnal_cost|
#           physical_road_conditionnal_cost.update_attribute :physical_road_id, pr.id
#           prcc << physical_road_conditionnal_cost
#         end
#       end        
#       ActiveRoad::PhysicalRoadConditionnalCost.import(prcc)               
#     end


#     class Node
#       attr_accessor :id, :geometry, :ways, :end_of_way

#       def initialize(id, geometry, ways = [], end_of_way = false)
#         @id = id
#         @geometry = geometry
#         @ways = ways
#         @end_of_way = end_of_way
#       end

#       def add_way(id)
#         @ways << id
#       end

#       def marshal_dump
#         [@id, @geometry, @ways, @end_of_way]
#       end
      
#       def marshal_load array
#         @id, @geometry, @ways, @end_of_way = array
#       end
#     end

#   end
# end
