require "active_road/engine"
require 'erb'
require 'saxerator'
require "activerecord-postgis-adapter"
require "enumerize"
require "pbf_parser"
require 'postgres-copy'
require 'snappy'

# Hack to delete to use bundler https://github.com/guard/guard-rspec/issues/258
require "thor"

module ActiveRoad

  def self.srid
    4326
  end

  # def self.database_configuration
  #   YAML::load(ERB.new(IO.read( File.expand_path('../../config/database.yml', __FILE__))).result)
  # end
  
end
