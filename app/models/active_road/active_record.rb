require 'postgis_adapter'

class ActiveRoad::ActiveRecord < ActiveRecord::Base
  self.abstract_class = true

  # establish_connection :roads doesn't work :(
  if const_defined?("Rails")
    establish_connection Rails.configuration.database_configuration["roads"]
  end
end
