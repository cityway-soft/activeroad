require 'leveldb-native'
require 'csv'

module ActiveRoad
  class TerraImporter
    
    attr_reader :parser, :xml_file, :prefix_path, :physical_roads_database_path, :junctions_database_path 

    def initialize(xml_file, prefix_path = "/tmp")
      @xml_file = xml_file
      @prefix_path = prefix_path

      FileUtils.mkdir_p(prefix_path) if !Dir.exists?(prefix_path)
      @junctions_database_path = prefix_path + "/osm_pbf_junctions_leveldb"
      @physical_roads_database_path = prefix_path + "/osm_pbf_physical_roads_leveldb"
    end

    def junctions_database
      @junctions_database ||= LevelDBNative::DB.make junctions_database_path, :create_if_missing => true, :block_cache_size => 16 * 1024 * 1024
    end

    def close_junctions_database
      junctions_database.close!
    end

    def delete_junctions_database
      FileUtils.remove_entry junctions_database_path if File.exists?(junctions_database_path)
    end

    def physical_roads_database
      @physical_roads_database ||= LevelDBNative::DB.make physical_roads_database_path, :create_if_missing => true, :block_cache_size => 16 * 1024 * 1024
    end
    
    def close_physical_roads_database
      physical_roads_database.close!
    end

    def delete_physical_roads_database
      FileUtils.remove_entry physical_roads_database_path if File.exists?(physical_roads_database_path)
    end

    def parser
      @parser ||= ::Saxerator.parser(File.new(xml_file))
    end

    def display_time(time_difference)
      Time.at(time_difference.to_i).utc.strftime "%H:%M:%S"
    end
    
    def import
      delete_junctions_database
      delete_physical_roads_database
      
      street_numbers = parser.for_tag(:StreetNumber)
      trajectory_nodes = parser.for_tag(:TrajectoryNode)
      trajectory_arcs = parser.for_tag(:TrajectoryArc)
      
      import_street_numbers(street_numbers)
      import_junctions(trajectory_nodes)
      import_physical_roads(trajectory_arcs)

      save_junctions_and_physical_roads_temporary
      import_physical_road_conditionnal_costs_and_junctions_physical_roads(trajectory_arcs)      
    end

    def import_street_numbers(street_numbers)
      Rails.logger.debug "Begin to save street_numbers in PostgreSql"
      
      start = Time.now
      street_numbers_counter = 0
      
      # traverse records by iterator
      street_number_columns = ["objectid", "geometry", "number", "location_on_road", "created_at", "updated_at"]
      
      CSV.open("#{prefix_path}/street_numbers.csv", "wb:UTF-8") do |street_numbers_csv|                  
        street_numbers_csv << street_number_columns
        
        street_numbers.each do |street_number|
          geometry = RgeoExt.geos_factory.parse_wkt(street_number["Geometry"])
          
          street_numbers_csv << [ street_number["ObjectId"], geometry.as_text, street_number["Number"], street_number["LocationOnArc"], Time.now, Time.now ]
        end
          
      end
      
      ActiveRoad::StreetNumber.transaction do
        ActiveRoad::StreetNumber.copy_from "#{prefix_path}/street_numbers.csv"
      end
      
      Rails.logger.info "Finish to save #{street_numbers_counter} street numbers in PostgreSql in #{display_time(Time.now - start)} seconds"         
             
    end

    def import_junctions(trajectory_nodes)
      Rails.logger.debug "Begin to save junctions in PostgreSql"
      
      start = Time.now
      junctions_counter = 0
      
      # traverse records by iterator
      junction_columns = ["objectid", "geometry", "height", "created_at", "updated_at"]
      
      CSV.open("#{prefix_path}/junctions.csv", "wb:UTF-8") do |junctions_csv|                
        junctions_csv << junction_columns
        
        trajectory_nodes.each do |trajectory_node|
          junctions_counter += 1
          
          geometry = RgeoExt.geos_factory.parse_wkt(trajectory_node["Geometry"])
          junctions_csv << [ trajectory_node["ObjectId"], geometry.as_text, trajectory_node["Height"], Time.now, Time.now ]          
        end
      end
      
      ActiveRoad::Junction.transaction do                                         
        ActiveRoad::Junction.copy_from "#{prefix_path}/junctions.csv"
      end
      
      Rails.logger.info "Finish to backup #{junctions_counter} junctions in PostgreSql in #{display_time(Time.now - start)} seconds"         
      
    end

    def import_physical_roads(trajectory_arcs)
      Rails.logger.info "Begin to save physical_roads in PostgreSql"
      start = Time.now
   
      ways_counter = 0

      # traverse records by iterator
      physical_road_columns = ["objectid", "geometry", "length", "created_at", "updated_at"]
      
      CSV.open("#{prefix_path}/physical_roads.csv", "wb:UTF-8") do |physical_roads_csv|
        physical_roads_csv << physical_road_columns
          
        trajectory_arcs.each do |trajectory_arc|        
          ways_counter += 1
          
          geometry = RgeoExt.geos_factory.parse_wkt(trajectory_arc["Geometry"])
          length = geometry.length
            
          physical_roads_csv << [ trajectory_arc["ObjectId"], geometry.as_text, length, Time.now, Time.now ]
        end
      end
      
      # Save physical roads
      ActiveRoad::PhysicalRoad.transaction do                                         
        ActiveRoad::PhysicalRoad.copy_from "#{prefix_path}/physical_roads.csv"
      end

      Rails.logger.info "Finish to save #{ways_counter} physical_roads in PostgreSql in #{display_time(Time.now - start)} seconds"
    end

    def save_junctions_and_physical_roads_temporary
      Rails.logger.info "Begin to backup physical_roads and junctions in LevelDb"
      
      start = Time.now      
      junctions_database.batch do |batch|
        ActiveRoad::Junction.pluck("id,objectid").each do |junction|
          junctions_database[junction.last] = junction.first.to_s
        end
      end

      physical_roads_database.batch do |batch|
        ActiveRoad::PhysicalRoad.pluck("id,objectid").each do |physical_road|
          physical_roads_database[physical_road.last] = physical_road.first.to_s
        end
      end

      Rails.logger.info "Finish to backup physical_roads and junctions in LevelDb in #{display_time(Time.now - start)} seconds"
    end   

    def import_physical_road_conditionnal_costs_and_junctions_physical_roads(trajectory_arcs)
      Rails.logger.info "Begin to backup physical_road_conditionnal_costs and junctions_physical_roads in PostgreSql"
      
      start = Time.now
      physical_road_conditionnal_costs_counter = junctions_physical_roads_counter = 0
      physical_road_conditionnal_cost_columns = ["tags", "cost", "physical_road_id"]
      junction_physical_road_columns = ["physical_road_id", "junction_id"]
      
      CSV.open("#{prefix_path}/physical_road_conditionnal_costs.csv", "wb:UTF-8") do |physical_road_conditionnal_costs_csv|
        CSV.open("#{prefix_path}/junctions_physical_roads.csv", "wb:UTF-8") do |junctions_physical_roads_csv|
          physical_road_conditionnal_costs_csv << physical_road_conditionnal_cost_columns
          junctions_physical_roads_csv << junction_physical_road_columns
          
          trajectory_arcs.each do |trajectory_arc|
            trajectory_arc["TrajectoryNodeRef"].each do |junction_objectid|
              junction_id = junctions_database[junction_objectid]
              junctions_physical_roads_counter += 1
              junctions_physical_roads_csv << [ physical_roads_database[trajectory_arc["ObjectId"]], junction_id ] if junction_id.present?
            end if trajectory_arc["TrajectoryNodeRef"].present?
            
          end
        end
      end
      
      # Save physical road conditionnal costs
      ActiveRoad::PhysicalRoadConditionnalCost.transaction do                                         
        ActiveRoad::PhysicalRoadConditionnalCost.copy_from "#{prefix_path}/physical_road_conditionnal_costs.csv"
      end

      # Save physical road and junctions link
      ActiveRoad::JunctionsPhysicalRoad.transaction do                                         
        ActiveRoad::JunctionsPhysicalRoad.copy_from "#{prefix_path}/junctions_physical_roads.csv"
      end

      Rails.logger.info "Finish to backup #{junctions_physical_roads_counter} junctions_physical_roads and #{physical_road_conditionnal_costs_counter} physical_road_conditionnal_costs in PostgreSql in #{display_time(Time.now - start)} seconds"
    end

  end
end
