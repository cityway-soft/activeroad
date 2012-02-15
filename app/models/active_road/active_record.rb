class ActiveRoad::ActiveRecord < ActiveRecord::Base
  self.abstract_class = true

  establish_connection :roads
end
