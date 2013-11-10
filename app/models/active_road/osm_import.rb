require 'kyotocabinet'

class  ActiveRoad::OsmImport
  include KyotoCabinet
  
  attr_reader :parser, :database_path, :xml_file

  # See for more details :  
  # http://wiki.openstreetmap.org/wiki/FR:France_roads_tagging
  # http://wiki.openstreetmap.org/wiki/FR:Cycleway
  # http://wiki.openstreetmap.org/wiki/Key:railway
  @@tag_for_car_values = %w{motorway trunk trunk_link primary secondary tertiary motorway_link primary_link unclassified service road residential track}
  cattr_reader :tag_for_car_values

  @@tag_for_pedestrian_values = %w{pedestrian footway path steps}
  cattr_reader :tag_for_pedestrian_values

  @@tag_for_bike_values = ActiveRoad::OsmImport.tag_for_pedestrian_values + ["cycleway"]
  cattr_reader :tag_for_bike_values

  @@tag_for_train_values = %w{rail tram funicular light_rail subway}
  cattr_reader :tag_for_train_values

  def initialize(xml_file, database_path = "/tmp/osm.kch")
    @xml_file = xml_file
    @parser = select_parser(xml_file)
    @database_path = database_path
  end

  def select_parser(xml_file)
    case xml_file
    when /.osm.bz2/ # TODO : Test bzip2
      # ::Bzip2::Reader.open(xml_file) do |xml_file_unzip|
      #   parser = ::Saxerator.parser(File.new(xml_file_unzip))
      # end
    when /.osm/
      parser = ::Saxerator.parser(File.new(xml_file))
    else
      # TODO :  Throw file extension error
      Rails.logger.error "Error : file extension is not recognized"
    end
    parser    
  end

  def database
    @database ||= DB::new
  end

  def open_database(path)
    database.open(path, DB::OWRITER | DB::OCREATE)
    database.clear
  end

  def close_database
    database.close   
  end

  def authorized_tags
    @authorized_tags ||= ["highway", "railway"]
  end

  # Return an hash with tag_key => tag_value for osm attributes
  def extracted_tags(tags)
    {}.tap do |extracted_tags|
      if tags.size == 0 && authorized_tags.include?(tags.attributes["k"])
        extracted_tags[tags.attributes["k"]] = tags.attributes["v"]
      else
        tags.each do |tag|
          if authorized_tags.include?(tag.attributes["k"])
            extracted_tags[tag.attributes["k"]] = tag.attributes["v"]
          end
        end    
      end       
    end
  end

  def physical_road_conditionnal_costs(tags)
    [].tap do |prcc|
      tags.each do |tag_key, tag_value|
        if ["highway", "railway"].include?(tag_key)
          prcc << ActiveRoad::PhysicalRoadConditionnalCost.new(:tags => "car", :cost => Float::INFINITY) if !ActiveRoad::OsmImport.tag_for_car_values.include?(tag_value)  
          prcc << ActiveRoad::PhysicalRoadConditionnalCost.new(:tags => "pedestrian", :cost => Float::INFINITY) if !ActiveRoad::OsmImport.tag_for_pedestrian_values.include?(tag_value)
          prcc << ActiveRoad::PhysicalRoadConditionnalCost.new(:tags => "bike", :cost => Float::INFINITY) if !ActiveRoad::OsmImport.tag_for_bike_values.include?(tag_value) 
          prcc << ActiveRoad::PhysicalRoadConditionnalCost.new(:tags => "train", :cost => Float::INFINITY) if !ActiveRoad::OsmImport.tag_for_train_values.include?(tag_value)
        end
      end
    end
  end
  
  def backup_nodes(database)
    # Save nodes in kyotocabinet database
    parser.for_tag(:node).each do |node|
      database[ node.attributes["id"] ] = Marshal.dump(Node.new(node.attributes["id"], node.attributes["lon"].to_f, node.attributes["lat"].to_f))
    end 
  end

  def update_node_with_way(way, database)
    way_id = way.attributes["id"]
    # Get node ids for each way
    node_ids = []
    if way.key?("nd")
      nodes = way["nd"]

      if nodes.size == 0
        node_ids << nodes.attributes["ref"]
      else          
        nodes.each do |node|
          node_ids << node.attributes["ref"]
        end
      end
    end

    # Update node data with way id
    node_ids.each_with_index do |id, index|
      database.accept(id) { |key, value|
        node = Marshal.load(value)
        node.add_way(way_id)
        Marshal.dump(node)
      }
    end
  end
  
  def iterate_nodes(database)
    junctions_values = []    
    junctions_ways = {}
    # traverse records by iterator
    database.each { |key, value|
      
      node = Marshal.load(value)
      geometry = GeoRuby::SimpleFeatures::Point.from_x_y( node.lon, node.lat, 4326) if( node.lon && node.lat )    
      if node.ways.present? # Take node only if at least one way use it
        junctions_values << [ node.id, geometry ]
        junctions_ways[node.id] = node.ways
      end
      
      if junctions_values.count == 1000
        save_junctions(junctions_values, junction_ways) 
        #Reset
        junctions_values = []    
        junctions_ways = {}
      end
    }    
    save_junctions(junctions_values, junctions_ways) if junctions_values.present?
  end

  def save_junctions(junctions_values, junctions_ways)
    junction_columns = [:objectid, :geometry]
    # Save junctions in the stack
    ActiveRoad::Junction.import(junction_columns, junctions_values, :validate => false) if junctions_values.present?

    # Link the junction with physical roads
    junctions_ways.each do |junction_objectid, way_objectids|
      junction = ActiveRoad::Junction.find_by_objectid(junction_objectid)
      
      physical_roads = ActiveRoad::PhysicalRoad.find_all_by_objectid(way_objectids)
      junction.physical_roads << physical_roads if physical_roads      
    end
  end

  def import
    # process the database by iterator
    DB::process(database_path) { |database|           
      database.clear
      backup_nodes(database)

      physical_roads = []
      physical_road_conditionnal_costs_by_objectid = {}
      parser.for_tag(:way).each do |way|
        way_id = way.attributes["id"]
      
        if way.key?("tag")
          tags = extracted_tags(way["tag"])

          if tags.present?          
            update_node_with_way(way, database)

            physical_road = ActiveRoad::PhysicalRoad.new :objectid => way_id
            physical_roads << physical_road
            physical_road_conditionnal_costs_by_objectid[physical_road.objectid] = physical_road_conditionnal_costs(tags)
          end
        end

        if (physical_roads.count == 1000)
          save_physical_roads_and_children(physical_roads, physical_road_conditionnal_costs_by_objectid)
          
          # Reset  
          physical_roads = []
          physical_road_conditionnal_costs_by_objectid = {}
        end
      end
      
      save_physical_roads_and_children(physical_roads, physical_road_conditionnal_costs_by_objectid) if physical_roads.present?       

      iterate_nodes(database)
    }      
  end

  def save_physical_roads_and_children(physical_roads, physical_road_conditionnal_costs_by_objectid = {})
    # Save physical roads
    ActiveRoad::PhysicalRoad.import(physical_roads)

    # Save physical road conditionnal costs
    prcc = []
    physical_road_conditionnal_costs_by_objectid.each do |objectid, physical_road_conditionnal_costs|
      pr = ActiveRoad::PhysicalRoad.where(:objectid => objectid).first
      physical_road_conditionnal_costs.each do |physical_road_conditionnal_cost|
        physical_road_conditionnal_cost.update_attribute :physical_road_id, pr.id
        prcc << physical_road_conditionnal_cost
      end
    end        
    ActiveRoad::PhysicalRoadConditionnalCost.import(prcc)               
  end

  class Node
    attr_accessor :id, :lon, :lat, :ways

    def initialize(id, lon, lat, ways = [])
      @id = id
      @lon = lon
      @lat = lat
      @ways = ways
    end

    def add_way(id)
      @ways << id
    end

    def marshal_dump
      [@id, @lon, @lat, @ways]
    end
    
    def marshal_load array
      @id, @lon, @lat, @ways = array
    end
  end

end
