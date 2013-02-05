class ActiveRoad::Base < ActiveRecord::Base
  self.abstract_class = true

  establish_connection :roads if configurations["roads"].present?
end
