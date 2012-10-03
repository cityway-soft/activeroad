source "http://rubygems.org"

# Specify your gem's dependencies in activeroad.gemspec
gemspec

group :development do
  # gem 'activeosm', :git => 'git://roads.dryade.priv/activeosm', :ref => '71f4cc9c6477ec5fbc090576f4dd3b20666b6722' #, :path => '~/Projects/ActiveOSM'
  gem 'postgis_adapter', :git => 'git://github.com/dryade/postgis_adapter.git' #, :path => "~/Projects/PostgisAdapter"
  gem 'georuby-ext', :git => 'git://github.com/dryade/georuby-ext.git', :ref => 'c1c55b8' #, :path => "~/Projects/GeoRubyExt"
  gem 'shortest_path', :git => 'git://github.com/dryade/shortest_path.git' #, :path => "~/Projects/ShortestPath"
  gem "ffi-proj4", :git => 'git://github.com/dryade/ffi-proj4.git'

  group :linux do
    gem 'rb-inotify'
    gem 'libnotify'
  end
end
