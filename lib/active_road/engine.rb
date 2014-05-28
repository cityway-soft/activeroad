module ActiveRoad
  if defined?(Rails)
    require "active_road/migration"

    class Engine < ::Rails::Engine
      #isolate_namespace ActiveRoad
      
      config.generators do |g|
        g.test_framework :rspec
      end
      
      initializer "active_road.factories", :after => "factory_girl.set_factory_paths" do
        FactoryGirl.definition_file_paths << File.expand_path('../../../spec/factories', __FILE__) if defined?(FactoryGirl)
      end

    end
  end
end
