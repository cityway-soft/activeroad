# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../spec/dummy/config/environment", __FILE__)
require 'rspec/rails'
require 'rspec/autorun'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

require 'georuby-ext'

require 'factory_girl'
require File.expand_path('../factories.rb', __FILE__)

RSpec.configure do |config|
  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.mock_with :rspec

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false
end

# begin
#   require 'rspec'
# rescue LoadError
#   require 'rubygems' unless ENV['NO_RUBYGEMS']
#   require 'rspec'
# end

# $:.unshift(File.dirname(__FILE__) + '/../lib')
# require 'active_road'

# require 'active_record'
# # Requires supporting files with custom matchers and macros, etc,
# # in ./support/ and its subdirectories.
# Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

# require 'database_cleaner'
# require 'logger'

RSpec.configure do |config|
  config.around(:each) do |example|
    ActiveRecord::Base.transaction do
    begin
      example.run
      ensure
        puts "appel du rollback"
    raise ActiveRecord::Rollback
     end
    end
  end
end
