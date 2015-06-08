#!/usr/bin/env/ruby
require 'ruby-prof'

# Se placer dans le contexte de l'application rails
# cd spec/dummy
# bundle exec rails runner ../../script/benchmark_shortest_path.rb

departure = ActiveRoad::RgeoExt.cartesian_factory.point(2.3285425111107307, 48.850989640001636)
arrival = ActiveRoad::RgeoExt.cartesian_factory.point(2.3370497617265267, 48.85068570078048)
sp = ActiveRoad::ShortestPathFinder.new(departure, arrival, 4)

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
