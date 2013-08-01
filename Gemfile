source "http://rubygems.org"

# Specify your gem's dependencies in activeroad.gemspec
gemspec

# gem 'activeosm', :git => 'git://github.com/dryade/activeosm', :ref => '71f4cc9c6477ec5fbc090576f4dd3b20666b6722' #, :path => '~/Projects/ActiveOSM'
gem 'dr-postgis_adapter', '0.8.1', :require => "postgis_adapter"
# TODO: remove when shortest_path is available in 0.0.2
gem 'shortest_path', :git => 'https://github.com/dryade/shortest_path.git'

group :development do
  gem 'rails-erd'
  group :linux do
    gem 'rb-inotify', :require => RUBY_PLATFORM.include?('linux') && 'rb-inotify'
    gem 'rb-fsevent', :require => RUBY_PLATFORM.include?('darwin') && 'rb-fsevent'
  end
end
