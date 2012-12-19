namespace :ci do
  task :db_travis_config do
    cp "config/database.yml.travis", "config/database.yml"
  end
end
