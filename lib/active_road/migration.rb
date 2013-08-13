class ActiveRoad::Migration < ActiveRecord::Migration
#   def connection
#     # @connection can be wrapped (with CommandRecorder in Rails 3.2 for example)
#     if roads_connection?(@connection)
#       @connection
#     else
#       @connection = ActiveRoad::Base.connection
#     end
#   end
  
#   def roads_connection?(connection)
#     connection.respond_to?(:current_database) and 
#       connection.current_database == ActiveRoad::Base.connection.current_database
#   end
end
