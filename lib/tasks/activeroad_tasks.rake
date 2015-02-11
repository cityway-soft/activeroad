# -*- coding: utf-8 -*-
require "csv"

namespace :active_road do

  desc 'This rebuilds environment db'
  task :reset => :environment do 
    Rake::Task["db:drop"].invoke
    Rake::Task["db:create"].invoke
    Rake::Task["db:migrate"].invoke
  end
  
  namespace :import do

    # bundle exec rake "app:active_road:import:filter_osm_pbf_data[/home/user/test.osm.pbf, /home/luc/Dropbox/cityway/navtec/architecture/emprise_toronto.poly]"
    desc "Filter osm pbf data with a polygon"    
    task :filter_osm_pbf_data, [:file, :poly_file] => [:environment] do |task, args|
      puts "Filter data from osm pbf file #{args.file}"
      raise "You should provide a valid osm file" if args.file.blank?
      raise "You should provide a valid poly file" if args.poly_file.blank?
      sh %Q{osmosis --read-pbf file="#{args.file}" --bounding-polygon file="#{args.poly_file}" completeWays=yes completeRelations=yes  --sort type="TypeThenId" --write-pbf file="ontario_mtx.osm.pbf"}
    end

    # bundle exec rake "app:active_road:import:osm_pbf_data[/home/user/test.osm.pbf, true]"
    desc "Import osm data from a pbf file"
    task :osm_pbf_data, [:file, :split_ways, :split_boundaries, :prefix_path] => [:environment] do |task, args|      
      begin
        puts "Import data from osm pbf file #{args.file} and with split_ways #{args.split_ways} and with split ways with boundaries #{args.split_boundaries} and with prefix path #{args.prefix_path}"
        raise "You should provide a valid osm file" if args.file.blank?
        split_ways = args.split_ways == "true" ? true : false
        split_boundaries = args.split_boundaries == "true" ? true : false
        prefix_path = args.prefix_path.present? ? args.prefix_path : "/tmp"
        ActiveRoad::OsmPbfImporterLevelDb.new(args.file, split_ways, split_boundaries, prefix_path).import
        puts "Completed import successfully."    
      rescue => e
        puts("Failed to import osm data : " + e.message)
        puts e.backtrace.join("\n")
      end    
    end    

    desc "Import terra data from a terra file"
    task :terra_data, [:file] => [:environment] do |task, args|      
      begin
        puts "Import data from terra file #{args.file}"
        raise "You should provide a valid osm file" if args.file.blank?
        start = Time.now
        ActiveRoad::TerraImporter.new(args.file).import
        #puts "OSM import finished in #{(Time.now - start).strftime('%H:%M:%S')} seconds"
        puts "Completed import successfully."    
      rescue => e
        puts("Failed to import terra data : " + e.message)
        puts e.backtrace.join("\n")
      end    
    end

  end

  namespace :report do

    desc "Create csv file reports to list invalid street numbers"
    task :invalid_street_numbers => [:environment] do |task, args|
      FileUtils.mkdir_p("/tmp/reports") if !Dir.exists?("/tmp/reports")      
      street_number_without_road_counter = street_number_far_from_road_counter = 0
            
      CSV.open("/tmp/reports/street_number_without_road.csv", "wb:UTF-8") do |street_numbers_csv|
        street_numbers_csv << ["id", "objectid", "geometry"]
        
        ActiveRoad::StreetNumber.where("physical_road_id IS NULL").each do |street_number|
          street_number_without_road_counter += 1
          street_numbers_csv << [street_number.id, street_number.objectid, street_number.geometry]
        end
      end

      puts "You can see #{street_number_without_road_counter} street number without road in /tmp/reports/street_number_without_road.csv"
            
      CSV.open("/tmp/reports/street_number_far_from_road.csv", "wb:UTF-8") do |street_numbers_csv|
        street_numbers_csv << ["id", "objectid", "geometry"]
        
        ActiveRoad::StreetNumber.joins(:physical_road).where("st_distance(street_numbers.geometry, physical_roads.geometry, true) > 100 AND street_numbers.physical_road_id = physical_roads.id AND street_numbers.physical_road_id IS NOT NULL").each do |street_number|
          street_number_far_from_road_counter += 1
          street_numbers_csv << [street_number.id, street_number.objectid, street_number.geometry]
        end
      end

      puts "You can see #{street_number_far_from_road_counter} street number far from road in /tmp/reports/street_number_far_from_road.csv"
      
    end

    desc "Count objects in database"
    task :database_statistics => [:environment] do |task, args|
      puts "physical_roads : #{ActiveRoad::PhysicalRoad.count} elements"
      puts "junctions : #{ActiveRoad::Junction.count} elements"
      puts "street_numbers : #{ActiveRoad::StreetNumber.count} elements"
      puts "boundaries : #{ActiveRoad::Boundary.count} elements"
      puts "logical_roads : #{ActiveRoad::LogicalRoad.count} elements"
    end
    
  end

  desc "Launch an itinerary search"
  task :itinerary, [:from, :to, :speed, :constraints] => [:environment] do |task, args|      
    puts "Search an itinerary"
    raise "You should provide arguments" if args.from.blank? || args.to.blank? || args.speed.blank?
    start = Time.now
    begin
      finder = ActiveRoad::ShortestPath::Finder.new(args.from, args.to, args.speed, args.constraints).tap do |finder|
        finder.timeout = 30.seconds
      end
      puts "Itinerary in json : #{finder.to_json}"
    rescue => e
      puts("Failed to find an itinerary : " + e.message)
    end    
    puts "Itinerary research finished in #{(Time.now - start)} seconds"
  end
  
end
