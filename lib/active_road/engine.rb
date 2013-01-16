module ActiveRoad
  if defined?(Rails)
    require "active_road/migration"
    require 'active_record/connection_adapters/postgis_adapter/railtie'

    class Engine < ::Rails::Engine
    end
  end
end
