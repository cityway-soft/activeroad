# -*- coding: utf-8 -*-
require "pbf_parser"

class CountTagInOsmData
  
  def initialize(pbf_file, select_tags)
    @pbf_file = pbf_file
    @select_tags = eval(select_tags)
  end

  def has_select_tags?(tags)
    tags.each do |key, value|
      if (@select_tags.keys.include?(key) && @select_tags[key] == '*') || (@select_tags.keys.include?(key) && @select_tags[key] == value)
        return true
      end
    end
    return false
  end

  # def count_in_nodes
  #   p "Begin to backup nodes in LevelDB database in #{database_path}"
  #   start = Time.now
  #   nodes_parser = ::PbfParser.new(pbf_file)
  #   nodes_counter = 0
  #   nodes_hash = {}

  #   # Process the file until it finds any node
  #   nodes_parser.next until nodes_parser.nodes.any?
    
  #   until nodes_parser.nodes.empty?
  #     nodes_parser.nodes.each do |node|                
        
  #     end
  #     # When there's no more fileblocks to parse, #next returns false
  #     # This avoids an infinit loop when the last fileblock still contains ways
  #     break unless nodes_parser.next
  #   end
  #   p "Finish to backup #{nodes_counter} nodes in LevelDB database in #{(Time.now - start)} seconds"
  # end  

  def count_in_ways
    puts "Begin to count ways with specific tags"
    start = Time.now
    ways_parser = ::PbfParser.new(@pbf_file)
    ways_counter = 0 
    puts @select_tags.inspect
    # Process the file until it finds any way.
    ways_parser.next until ways_parser.ways.any?
    
    # Once it found at least one way, iterate to find the remaining ways.     
    until ways_parser.ways.empty?
      ways_parser.ways.each do |way|
        if way.key?(:tags)
          ways_counter += 1 if has_select_tags?(way[:tags])
        end        
      end        
      
      # When there's no more fileblocks to parse, #next returns false
      # This avoids an infinit loop when the last fileblock still contains ways
      break unless ways_parser.next        
    end

    p "Finish to count #{ways_counter} ways with specific tags  in #{(Time.now - start)} seconds"
  end
  
end

#ruby count_tag_in_osm_data.rb "/home/luc/Téléchargements/corse-latest.osm.pbf" "{'cycleway:left' => '*', 'cycleway:right' => '*', 'cycleway:both' => '*', 'cycleway' => '*', 'highway' => 'cycleway'}"
CountTagInOsmData.new(ARGV[0], ARGV[1]).count_in_ways
