source "http://rubygems.org"

# Specify your gem's dependencies in activeroad.gemspec
gemspec

group :development do
  gem 'activeosm', :git => 'git://roads.dryade.priv/activeosm', :require => 'active_osm' #, :path => '~/Projects/ActiveOSM'
  gem 'postgis_adapter', :git => 'git://github.com/dryade/postgis_adapter.git' #, :path => "~/Projects/PostgisAdapter"
  gem 'georuby-ext', :git => 'git://github.com/dryade/georuby-ext.git', :ref => 'c1c55b8' #, :path => "~/Projects/GeoRubyExt"
  gem 'progressbar'
  gem 'nokogiri'
  gem 'bzip2-ruby'
  gem 'shortest_path', :git => 'git://github.com/dryade/shortest_path.git' #, :path => "~/Projects/ShortestPath"
  gem "ffi-proj4", :git => 'git://github.com/dryade/ffi-proj4.git'

  group :linux do
    gem 'rb-inotify'
    gem 'libnotify'
  end
end
