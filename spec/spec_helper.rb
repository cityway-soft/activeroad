begin
  require 'rspec'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  require 'rspec'
end

$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'active_road'

require 'active_record'

Dir[File.dirname(__FILE__) + '/../app/**/*.rb'].sort.each {|f| require f}

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

require 'factory_girl'
require File.expand_path('../factories.rb', __FILE__)

require 'database_cleaner'
require 'logger'

RSpec.configure do |config|

  config.before(:suite) do
    ActiveRoad::ActiveRecord.logger = Logger.new("log/test.log")

    # Use DatabaseCleaner::ActiveRoad
    DatabaseCleaner[:active_road, {:connection => :default}]

    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation, :except => %w[spatial_ref_sys geometry_columns])
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

end
