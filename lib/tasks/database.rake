namespace :db do
  desc "Migrate the database (options: VERSION=x, VERBOSE=false)."
  task :migrate do
    require 'active_record'

    require 'active_road'
    require 'postgis_adapter'

    ActiveRecord::Base.establish_connection ActiveRoad.database_configuration["default"]

    ActiveRecord::Migration.verbose = (ENV["VERBOSE"] == "true")
    ActiveRecord::Migrator.migrate(%w{db/migrate}, ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
  end
end
