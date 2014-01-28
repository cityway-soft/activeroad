require 'kyotocabinet'
include KyotoCabinet

class Node
  attr_accessor :id, :lon, :lat, :ways, :end_of_way
  
  def initialize(id, lon, lat, ways = [], end_of_way = false)
    @id = id
    @lon = lon
    @lat = lat
    @ways = ways
    @end_of_way = end_of_way
  end
  
  def add_way(id)
    @ways << id
  end
  
  def marshal_dump
    [@id, @lon, @lat, @ways, @end_of_way]
  end
  
  def marshal_load array
    @id, @lon, @lat, @ways, @end_of_way = array
  end
end

class KCImport  
  
  def initialize(rnum, database_path = "/tmp/test.kch", options = "")
    @rnum = rnum
    @database_path = database_path
    @options = options
  end

  # def database
  #   @database = DB::new
  # end
  
  def memoryusage()
    rss = -1
    file = open('/proc/self/status')
    file.each do |line|
      if line =~ /^VmRSS:/
        line.gsub!(/.*:\s*(\d+).*/, '\1')
        rss = line.to_i / 1024.0
        break
      end
    end
    return rss
  end

  def import
    DB::process(@database_path + @options, DB::OWRITER | DB::OCREATE | DB::OTRUNCATE) { |database|
      
      #GC.start
      musage = memoryusage 
      stime = Time.now
      
      (0...@rnum).each do |i|     
        i_s = i.to_s
        key = i_s
        value = Marshal.dump(Node.new(i_s, rand, rand))
        database[key] = value
      end
      
      etime = Time.now
      #GC.start
      
      printf("Count: %d\n", database.count)
      printf("Time: %.3f sec.\n", etime - stime)
      printf("Usage: %.3f MB\n", memoryusage - musage)
      
    }
  end

  def import_and_update
    DB::process(@database_path + @options, DB::OWRITER | DB::OCREATE | DB::OTRUNCATE) { |database|
      
      #GC.start
      musage = memoryusage 
      stime = Time.now
      
      (0...@rnum).each do |i|     
        i_s = i.to_s
        key = i_s
        value = Marshal.dump(Node.new(i_s, rand, rand))
        database[key] = value
      end

      database.transaction {
        (0...100000).each do |way|
          update_node_with_way(way, database)
        end
      }
      
      etime = Time.now
      #GC.start
      
      printf("Count: %d\n", database.count)
      printf("Time: %.3f sec.\n", etime - stime)
      printf("Usage: %.3f MB\n", memoryusage - musage)
      
    }
  end

  def update_node_with_way(way, database)
    way_id = way.to_s
    nodes = [rand(6000000), rand(6000000), rand(6000000), rand(6000000), rand(6000000), rand(6000000), rand(6000000)]
    
    # Take only the first and the last node => the end of physical roads
    node_ids = nodes.collect(&:to_s)  
    
    # Update node data with way id
    database.accept_bulk(node_ids) { |key, value|
      node = Marshal.load(value)
      node.add_way(way_id)
      node.end_of_way = true if [nodes.first.to_s, nodes.last.to_s].include?(node.id)
      Marshal.dump(node)
    }
  end
  
end

rnum = 6000000
if ARGV.length > 0
  rnum = ARGV[0].to_i
end

# if ARGV.length > 1
#   database_path = ARGV[1]
# end

# import in KC without options
puts "Import without options"
KCImport.new(rnum, "/home/luc/import_without_options.kch").import_and_update
# import in KC with options apow=8, opts=l, bnum=2000000 and msiz=50000000
puts "\n Import with options apow=8, opts=l, bnum=2000000 and msiz=50000000"
KCImport.new(rnum, "/home/luc/import_with_options.kch", "#apow=8#opts=l#bnum=2000000#msiz=50000000").import_and_update
