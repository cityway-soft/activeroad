source "http://rubygems.org"

# Specify your gem's dependencies in activeroad.gemspec
gemspec

gem 'dr-postgis_adapter', :path => "/home/luc/projects/postgis_adapter"
gem 'coveralls', require: false

group :development do
  gem "rails-erd" # Tool to make schema class
  group :linux do
    gem 'rb-inotify', :require => RUBY_PLATFORM.include?('linux') && 'rb-inotify'
    gem 'rb-fsevent', :require => RUBY_PLATFORM.include?('darwin') && 'rb-fsevent'
  end
end

group :development, :test do
  gem "ruby-prof"
  gem "bullet"
end
