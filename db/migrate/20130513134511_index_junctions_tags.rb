class IndexJunctionsTags < ActiveRecord::Migration
  def up
    execute "CREATE INDEX junctions_tags ON junctions USING GIN(tags)"
  end
  
  def down
    execute "DROP INDEX junctions_tags"
  end
end
