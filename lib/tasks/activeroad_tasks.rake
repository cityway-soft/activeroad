namespace :active_road do
  namespace :import do
 
    # 
    desc "Import osm data from an osm file"
    task :osm_data, ["file"] => [:environment] do |task, args|      
      begin
        puts "Import data from osm file #{args.file}"
        raise "You should provide a valid osm file" if args.file.blank?
        ActiveRoad::OsmImport.new(args.file).import
        puts "Completed import successfully."    
      rescue => e
        puts("Failed to import osm data : " + e.message)
      end    
    end

    desc "Import terra data from a terra file"
    task :terra_data, [:file] => [:environment] do |task, args|      
      begin
        puts "Import data from terra file #{args.file}"
        raise "You should provide a valid osm file" if args.file.blank?
        ActiveRoad::TerraImport.new(args.file).extract
        puts "Completed import successfully."    
      rescue => e
        puts("Failed to import terra data : " + e.message)
      end    
    end

  end
end
