namespace :activeroad do
  namespace :db do
    desc "Migrate the database (options: VERSION=x, VERBOSE=false)."

    task :migrate do
      require 'active_record'

      require 'active_road'
      require "active_road/migration"
      require 'postgis_adapter'

      env = (ENV['RAILS_ENV'] or "default")
      ActiveRecord::Base.establish_connection ActiveRoad.database_configuration[env]

      ActiveRecord::Migration.verbose = (ENV["VERBOSE"] == "true")
      ActiveRecord::Migrator.migrate(%w{db/migrate}, ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
    end
    
  end
end
