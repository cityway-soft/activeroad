require "active_road/version"
require 'erb'

module ActiveRoad

  def self.srid
    4326
  end

  def self.database_configuration
    YAML::load(ERB.new(IO.read( File.expand_path('../../config/database.yml', __FILE__))).result)
  end

  if defined?(Rails)
    class Engine < Rails::Engine
    end
  end
  
end


