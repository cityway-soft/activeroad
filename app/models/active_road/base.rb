class ActiveRoad::Base < ActiveRecord::Base
  self.abstract_class = true

  establish_connection :roads
end
