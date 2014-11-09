# -*- coding: utf-8 -*-
namespace :active_road do

  desc 'This rebuilds environment db'
  task :reset => :environment do 
    Rake::Task["db:drop"].invoke
    Rake::Task["db:create"].invoke
    Rake::Task["db:migrate"].invoke
  end

  namespace :import do

    # bundle exec rake "app:active_road:import:osm_pbf_data[/home/user/test.osm.pbf, true]"
    desc "Import osm data from a pbf file"
    task :osm_pbf_data, [:file, :split_ways] => [:environment] do |task, args|      
      begin
        puts "Import data from osm pbf file #{args.file} and with split_ways #{args.split_ways} with LevelDB"
        raise "You should provide a valid osm file" if args.file.blank?
        split_ways = args.split_ways == "true" ? true : false
        ActiveRoad::OsmPbfImporterLevelDb.new(args.file, split_ways).import
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
