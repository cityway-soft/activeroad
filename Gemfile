source "http://rubygems.org"

# Specify your gem's dependencies in activeroad.gemspec
gemspec

gem 'activeosm', :git => 'git://github.com/dryade/activeosm', :ref => '71f4cc9c6477ec5fbc090576f4dd3b20666b6722' #, :path => '~/Projects/ActiveOSM' 
gem 'georuby-ext', :git => 'git://github.com/dryade/georuby-ext.git' #, :path => "~/projects/georuby-ext"
gem 'shortest_path', :git => 'git://github.com/dryade/shortest_path.git' #, :path => "~/Projects/ShortestPath"


group :development do
  gem 'rb-inotify', ">= 0.8.8", :require => RUBY_PLATFORM.include?('linux') && 'rb-inotify'
  gem 'libnotify', ">= 0.8.0", :require => RUBY_PLATFORM.include?('linux') && 'libnotify'
  gem 'rb-fsevent', ">= 0.9.3", :require => RUBY_PLATFORM.include?('darwin') && 'rb-fsevent'
end
