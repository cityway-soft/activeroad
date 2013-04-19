source "http://rubygems.org"

# Specify your gem's dependencies in activeroad.gemspec
gemspec

# gem 'activeosm', :git => 'git://github.com/dryade/activeosm', :ref => '71f4cc9c6477ec5fbc090576f4dd3b20666b6722' #, :path => '~/Projects/ActiveOSM' 
gem 'shortest_path', :git => 'git://github.com/dryade/shortest_path.git' #, :path => "~/Projects/ShortestPath"
gem 'postgis_adapter', :git => 'git://github.com/dryade/postgis_adapter.git'


group :development do
  group :linux do
    gem 'rb-inotify', :require => RUBY_PLATFORM.include?('linux') && 'rb-inotify'
    gem 'rb-fsevent', :require => RUBY_PLATFORM.include?('darwin') && 'rb-fsevent'        
  end
end
