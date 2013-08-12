source "http://rubygems.org"

# Specify your gem's dependencies in activeroad.gemspec
gemspec

gem 'dr-postgis_adapter', :require => "postgis_adapter"

group :development do
  gem 'rails-erd'
  group :linux do
    gem 'rb-inotify', :require => RUBY_PLATFORM.include?('linux') && 'rb-inotify'
    gem 'rb-fsevent', :require => RUBY_PLATFORM.include?('darwin') && 'rb-fsevent'
  end
end
