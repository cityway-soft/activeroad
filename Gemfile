source "http://rubygems.org"

# Specify your gem's dependencies in activeroad.gemspec
gemspec

# gem 'activeosm', :git => 'git://github.com/dryade/activeosm', :ref => '71f4cc9c6477ec5fbc090576f4dd3b20666b6722' #, :path => '~/Projects/ActiveOSM' 


group :development do
  group :linux do
    gem 'rb-inotify', :require => RUBY_PLATFORM.include?('linux') && 'rb-inotify'
    gem 'rb-fsevent', :require => RUBY_PLATFORM.include?('darwin') && 'rb-fsevent'        
  end
end
