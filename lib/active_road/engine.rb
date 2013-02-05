module ActiveRoad
  if defined?(Rails)
    require "active_road/migration"

    class Engine < ::Rails::Engine
    end
  end
end
