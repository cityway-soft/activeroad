require 'leveldb-native'

module ActiveRoad
  class OsmPbfImporterLevelDb
    include OsmPbfImporter

    @@kc_batch_size = 100000
    cattr_reader :kc_batch_size

    attr_reader :database_path, :pbf_file

    def initialize(pbf_file, database_path = "/tmp/osm_pbf_leveldb")
      @pbf_file = pbf_file
      @database_path = database_path
    end

    def database
      @database ||= LevelDBNative::DB.make database_path, :create_if_missing => true
    end

    def close_database
      database.close!
    end

    def delete_database
      FileUtils.remove_entry database_path if File.exists?(database_path)
    end
      
    def authorized_tags
      @authorized_tags ||= ["highway", "railway"]
    end
    
    def iterate_nodes
      p "Begin to backup nodes in PostgreSql"

      start = Time.now
      nodes_counter = 0
      junctions_values = []    
      junctions_ways = {}
      database_size = database.count
      
      # traverse records by iterator      
      database.each { |key, value|
        nodes_counter += 1
        node = Marshal.load(value)
        geometry = GeoRuby::SimpleFeatures::Point.from_x_y( node.lon, node.lat, 4326) if( node.lon && node.lat )
        
        if node.ways.present? && (node.ways.count >= 2 || node.end_of_way == true )  # Take node with at least two ways or at the end of a way
          junctions_values << [ node.id, geometry ]
          junctions_ways[ node.id ] = node.ways
        end        
        
        junction_values_size = junctions_values.size
        if junction_values_size > 0 && (junction_values_size == @@pg_batch_size || nodes_counter == database_size)
          backup_nodes_pgsql(junctions_values, junctions_ways)
          
          #Reset
          junctions_values = []    
          junctions_ways = {}
        end
      }    
      
      p "Finish to backup #{nodes_counter} nodes in PostgreSql in #{(Time.now - start)} seconds"         
    end
    
    def import
      delete_database
      
      backup_nodes_kc
      backup_ways_kc
      backup_ways_pgsql
      iterate_nodes
      
      close_database
    end

    def backup_nodes_kc
      p "Begin to backup nodes in LevelDB database in #{database_path}"
      start = Time.now
      nodes_parser = ::PbfParser.new(pbf_file)
      nodes_counter = 0
      nodes_hash = {}

      # Process the file until it finds any node
      nodes_parser.next until nodes_parser.nodes.any?
      
      until nodes_parser.nodes.empty?
        database.batch do |batch|
          last_node = nodes_parser.nodes.last
          nodes_parser.nodes.each do |node|
            nodes_counter+= 1
          
            database[ node[:id].to_s ] = Marshal.dump(Node.new(node[:id].to_s, node[:lon], node[:lat]))        
          end
end
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains ways
        break unless nodes_parser.next
      end
      p "Finish to backup #{nodes_counter} nodes in LevelDB database in #{(Time.now - start)} seconds"
    end  

    def backup_ways_kc
      puts "Begin to backup ways in nodes in LevelDB"
      start = Time.now
      ways_parser = ::PbfParser.new(pbf_file)
      ways_counter = 0 
      
      # Process the file until it finds any way.
      ways_parser.next until ways_parser.ways.any?
      
      # Once it found at least one way, iterate to find the remaining ways.     
      until ways_parser.ways.empty?
        ways_parser.ways.each do |way|
          ways_counter+= 1
          way_id = way[:id].to_s
          
          if way.key?(:tags) && required_way?(way[:tags])
            tags = selected_tags(way[:tags])             
            geometry = way_geometry(way)
            
            if geometry.present?
              update_node_with_way(way)               
            end
          end            
        end        
        
        # When there's no more fileblocks to parse, #next returns false
        # This avoids an infinit loop when the last fileblock still contains ways
        break unless ways_parser.next        
      end

      p "Finish to backup #{ways_counter} ways in nodes in LevelDB  in #{(Time.now - start)} seconds"
    end

    def update_node_with_way(way)
      way_id = way[:id].to_s
      # Get node ids for each way
      nodes = way.key?(:refs) ? way[:refs] : []
      node_ids = nodes.collect(&:to_s)  

      # Update node data with way id
      node_ids.each do |node_id|
        node = Marshal.load(database[node_id])
        node.add_way(way_id)
        node.end_of_way = true if [nodes.first.to_s, nodes.last.to_s].include?(node.id)
        database[node_id] = Marshal.dump(node)
      end
    end

  end
end
