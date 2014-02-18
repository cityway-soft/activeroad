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

  def count_in_nodes
    p "Begin to count nodes with specific tags"
    start = Time.now
    nodes_parser = ::PbfParser.new(@pbf_file)
    nodes_counter = 0
    puts @select_tags.inspect

    # Process the file until it finds any node
    nodes_parser.next until nodes_parser.nodes.any?
    
    until nodes_parser.nodes.empty?
      nodes_parser.nodes.each do |node|
        if node.key?(:tags) && has_select_tags?(node[:tags])
          nodes_counter += 1
        end        
      end
      # When there's no more fileblocks to parse, #next returns false
      # This avoids an infinit loop when the last fileblock still contains ways
      break unless nodes_parser.next
    end
    p "Finish to count #{nodes_counter} nodes with specific tags in #{(Time.now - start)} seconds"
  end  

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
        if way.key?(:tags) && has_select_tags?(way[:tags])          
          puts way.inspect if way[:id] == 31345618
          puts way.inspect if way[:id] == 31346056
          puts way.inspect if way[:id] == 31346749
          puts way.inspect if way[:id] == 31349698
          puts way.inspect if way[:id] == 31346058
          ways_counter += 1
        end        
      end        
      
      # When there's no more fileblocks to parse, #next returns false
      # This avoids an infinit loop when the last fileblock still contains ways
      break unless ways_parser.next        
    end

    p "Finish to count #{ways_counter} ways with specific tags  in #{(Time.now - start)} seconds"
  end

  def count_in_relations
    p "Begin to count relations with specific tags"
    start = Time.now
    relations_parser = ::PbfParser.new(@pbf_file)
    relations_counter = 0
    puts @select_tags.inspect

    # Process the file until it finds any relation
    relations_parser.next until relations_parser.relations.any?
    
    until relations_parser.relations.empty?
      relations_parser.relations.each do |relation|
        if relation.key?(:tags) && has_select_tags?(relation[:tags])
          relations_counter += 1
        end        
      end
      # When there's no more fileblocks to parse, #next returns false
      # This avoids an infinit loop when the last fileblock still contains ways
      break unless relations_parser.next
    end
    p "Finish to count #{relations_counter} relations with specific tags in #{(Time.now - start)} seconds"
  end  
  
end

#ruby count_tag_in_osm_data.rb "/home/luc/Téléchargements/corse-latest.osm.pbf" "{'cycleway:left' => '*', 'cycleway:right' => '*', 'cycleway:both' => '*', 'cycleway' => '*', 'highway' => 'cycleway'}" "ways"
if ARGV[2] == "nodes"
  CountTagInOsmData.new(ARGV[0], ARGV[1]).count_in_nodes
elsif ARGV[2] == "ways"
  CountTagInOsmData.new(ARGV[0], ARGV[1]).count_in_ways
elsif ARGV[2] == "relations"
  CountTagInOsmData.new(ARGV[0], ARGV[1]).count_in_relations
else
  CountTagInOsmData.new(ARGV[0], ARGV[1]).count_in_nodes
  CountTagInOsmData.new(ARGV[0], ARGV[1]).count_in_ways
  CountTagInOsmData.new(ARGV[0], ARGV[1]).count_in_relations
end
