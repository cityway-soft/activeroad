#!/usr/bin/env/ruby
require 'ruby-prof'

# Se placer dans le contexte de l'application rails
# cd spec/dummy
# bundle exec rails runner ../../script/benchmark_shortest_path.rb

departure = GeoRuby::SimpleFeatures::Point.from_x_y(7.699781, 48.587853)
arrival = GeoRuby::SimpleFeatures::Point.from_x_y(7.738061, 48.587853)
sp = ActiveRoad::ShortestPath::Finder.new(departure, arrival, 4)

# Profile the code
RubyProf.start
start = Time.now
sp.geometry
puts "request executed in #{(Time.now - start)} seconds"
result = RubyProf.stop

open("tmp/profile/callgrind.profile", "w") do |f|
  printer = ::RubyProf::CallTreePrinter.new(result)
  printer.print(f, :min_percent => 1)
end
