class IndexPhysicalRoadsTags < ActiveRecord::Migration
  def up
    execute "CREATE INDEX physical_roads_tags ON physical_roads USING GIN(tags)"
  end
  
  def down
    execute "DROP INDEX physical_roads_tags"
  end
end
