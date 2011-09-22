require "active_road/version"
require 'erb'

require 'active_road/geo_ruby_ext'

module ActiveRoad

  def self.database_configuration
    YAML::load(ERB.new(IO.read( File.expand_path('../../config/database.yml', __FILE__))).result)
  end
  
end


