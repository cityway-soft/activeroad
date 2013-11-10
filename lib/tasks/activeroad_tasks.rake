# -*- coding: utf-8 -*-
namespace :active_road do

  desc 'This rebuilds environment db'
  task :reset => :environment do 
    Rake::Task["db:drop"].invoke
    Rake::Task["db:create"].invoke
    Rake::Task["db:migrate"].invoke
  end

  namespace :import do
 
    # bundle exec rake "app:active_road:import:osm_data['/home/user/test.csv']"
    desc "Import osm data from an osm file"
    task :osm_data, [:file] => [:environment, :reset] do |task, args|      
      begin
        puts "Import data from osm file #{args.file}"
        raise "You should provide a valid osm file" if args.file.blank?
        start = Time.now
        ActiveRoad::OsmImport.new(args.file).import
        puts "OSM import finished in #{(Time.now - start)} seconds"
        puts "Completed import successfully."    
      rescue => e
        puts("Failed to import osm data : " + e.message)
      end    
    end

    desc "Import terra data from a terra file"
    task :terra_data, [:file] => [:environment, :reset] do |task, args|      
      begin
        puts "Import data from terra file #{args.file}"
        raise "You should provide a valid osm file" if args.file.blank?
        start = Time.now
        ActiveRoad::TerraImport.new(args.file).extract
        puts "Terra import finished in #{(Time.now - start)} seconds"
        puts "Completed import successfully."    
      rescue => e
        puts("Failed to import terra data : " + e.message)
      end    
    end

  end

#   nammespace :install do
#     task :dependencies do
#     end

#     task :kyotocabinet, [:file] => [:environment] do |task, args|      
#       sudo apt-get install -qq libgeos-dev libproj-dev postgresql-9.1-postgis liblzo2-dev liblzma-dev zlib1g-dev build-essential

# # Se placer dans le dossier /tmp
# cd /tmp

# # Installer kyotocabinet
# wget http://fallabs.com/kyotocabinet/pkg/kyotocabinet-1.2.76.tar.gz
# tar xzf kyotocabinet-1.2.76.tar.gz
# cd kyotocabinet-1.2.76
# ./configure –enable-zlib –enable-lzo –enable-lzma --prefix=/usr && make
# sudo make install

# # Installer les bindings ruby pour kyotocabinet
# cd /tmp
# wget http://fallabs.com/kyotocabinet/rubypkg/kyotocabinet-ruby-1.32.tar.gz
# tar xzf kyotocabinet-ruby-1.32.tar.gz
# cd kyotocabinet-ruby-1.32
# ruby extconf.rb
# make
# sudo make install
#     end
#   end

end
