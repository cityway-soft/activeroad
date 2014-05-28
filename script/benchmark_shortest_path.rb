#!/usr/bin/env/ruby
require 'ruby-prof'

# Se placer dans le contexte de l'application rails
# cd spec/dummy
# bundle exec rails runner ../../script/benchmark_shortest_path.rb

geos_factory = ::RGeo::Geos.factory(:native_interface => :ffi, :srid => 4326,
                                               :wkt_parser => {:support_ewkt => true, :default_srid => 4326},
                                               :wkt_generator => {:type_format => :ewkt, :emit_ewkt_srid => true},
                                               :wkb_parser => {:support_ewkb => true, :default_srid => 4326},
                                               :wkb_generator => {:type_format => :ewkb, :emit_ewkb_srid => true}
                                               )

departure = geos_factory.point(7.699781, 48.587853)
arrival = geos_factory.point(7.738061, 48.587853)
sp = ActiveRoad::ShortestPath::Finder.new(departure, arrival, 4)

# Profile the code
RubyProf.start
start = Time.now
puts sp.geometry.inspect
puts "request executed in #{(Time.now - start)} seconds"
result = RubyProf.stop

open("tmp/profile/callgrind.profile", "w") do |f|
  printer = ::RubyProf::CallTreePrinter.new(result)
  printer.print(f, :min_percent => 1)
end
