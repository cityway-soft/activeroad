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

  def transport_modes(tag_key, tag_value)
    transport_modes = []
    if tag_key == "highway"
      if ActiveRoad::OsmImport.tag_for_car_values.include?(tag_value)
        transport_modes << "car"
      end
      if ActiveRoad::OsmImport.tag_for_pedestrian_values.include?(tag_value)
        transport_modes << "pedestrian"
      end
      if ActiveRoad::OsmImport.tag_for_bike_values.include?(tag_value)
        transport_modes << "bike"
      end
    elsif ( tag_key == "railway" && ActiveRoad::OsmImport.tag_for_train_values.include?(tag_value) )
      transport_modes << "train"
    end

    transport_modes
  end
  
  def backup_nodes(database)
    # Save nodes in kyotocabinet database
    parser.for_tag(:node).each do |node|
      database.set(node.attributes["id"], Marshal.dump(Node.new(node.attributes["id"], node.attributes["lon"].to_f, node.attributes["lat"].to_f)) )
    end    
  end

  def update_node_with_ways(database)
    physical_roads_values = []

    parser.for_tag(:way).each do |way|
      # Fix the problem with dates
      way_id = way.attributes["id"]

      transport_modes = []
      node_ids = []
      
      if way.key?("tag")
        tags = way["tag"]
        if tags.size == 0
          if tags.attributes["k"] == "highway" || tags.attributes["k"] == "railway"
            transport_modes = transport_modes(tags.attributes["k"], tags.attributes["v"])
          end
        else
          tags.each do |tag|
            if tag.attributes["k"] == "highway" || tag.attributes["k"] == "railway"
              transport_modes = transport_modes(tag.attributes["k"], tag.attributes["v"])
            end
          end    
        end       
      end

      if transport_modes.present?
        
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
  
        # Update node data
        node_ids.each_with_index do |id, index|
          database.accept(id) { |key, value|
            node = Marshal.load(value)
            node.add_way(way_id)
            Marshal.dump(node)
          }
        end
        
        # Save way in postgresql database
        physical_roads_values << [ way_id ]
      end

      # Save physical roads in the stack
      save_physical_roads(physical_roads_values) if (physical_roads_values.count == 1000)      
    end

    # Save physical roads in the stack
    save_physical_roads(physical_roads_values) if physical_roads_values.present?        
  end

  def save_physical_roads(physical_roads_values)
    physical_road_columns = [:objectid]
    ActiveRoad::PhysicalRoad.import(physical_road_columns, physical_roads_values, :validate => false)
  end
  
  def iterate_nodes(database)
    junctions_values = []    
    junctions_ways = {}

    # traverse records by iterator
    database.each { |key, value|
      node = Marshal.load(value)
      geometry = GeoRuby::SimpleFeatures::Point.from_x_y( node.lon, node.lat, 4326) if( node.lon && node.lat )
      junctions_values << [ node.id, geometry ]
      junction_ways[node.id] = node.ways

      save_junctions(junctions_values, junction_ways) if junctions_values.count == 1000
    }    
    save_junctions(junctions_values, junctions_ways)
  end

  def save_junctions(junctions_values, junctions_ways)
    junction_columns = [:objectid, :geometry]

    # Save junctions in the stack
    ActiveRoad::Junction.import(junction_columns, junctions_values, :validate => false) if junctions_values.present?

    # Link the junction with physical roads
    junctions_ways.each do |junction_objectid, way_objectids|
      junction = ActiveRoad::Junction.find_by_objectid(junction_objectid)
      
      way_objectids.each do |way_objectid|
        physical_road = ActiveRoad::PhysicalRoad.find_by_objectid(way_objectid)
        junction.physical_roads << physical_road if physical_road
      end
      
    end
  end

  def import

    # process the database by iterator
    DB::process(database_path) { |database|           
      database.clear
      backup_nodes(database)
      update_node_with_ways(database)
      iterate_nodes(database)
    }      
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
