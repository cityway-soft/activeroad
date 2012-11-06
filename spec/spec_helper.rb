# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../dummy/config/environment", __FILE__)

require 'rspec/rails'
require 'rspec/autorun'

require 'factory_girl_rails'
require 'saxerator'

require 'database_cleaner'
require 'georuby-ext'

ENGINE_RAILS_ROOT=File.join(File.dirname(__FILE__), '../')

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  DatabaseCleaner.logger = Rails.logger
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

  #config.before :suite do
  #  DatabaseCleaner.strategy = :transaction
    #DatabaseCleaner.clean_with( :truncation, {:except => %w[spatial_ref_sys geometry_columns]} )
  #end
  # Request specs cannot use a transaction because Capybara runs in a
  # separate thread with a different database connection.
  # config.before type: :request do
  #   DatabaseCleaner.strategy = :truncation
  # end
  #config.before do
  #  DatabaseCleaner.start
  #end
  #config.after do
  #  DatabaseCleaner.clean
  #end

end
