$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'active_road'

# Load "manually" app code
require 'active_record'
Dir[File.dirname(__FILE__) + '/../app/**/*.rb'].sort.each {|f| require f}

# Establish database connection
ActiveRoad::ActiveRecord.establish_connection ActiveRoad.database_configuration["default"]


