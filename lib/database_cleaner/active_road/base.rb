module DatabaseCleaner
  class << self
    alias_method :orm_module_without_active_road, :orm_module

    def orm_module(symbol)
      if :active_road
        DatabaseCleaner::ActiveRoad
      else
        orm_module_without_active_road symbol
      end
    end
  end

  module ActiveRoad
    module Base
      def connection_klass
        load_config
        ::ActiveRoad::ActiveRecord.tap do |klass|
          unless klass.connected?
            klass.establish_connection(connection_hash) 
          end
        end
      end
    end
  end
end
