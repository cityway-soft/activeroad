# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130419155438) do

  create_table "junction_conditionnal_costs", :force => true do |t|
    t.column "junction_id", :integer
    t.column "cost", :float
    t.column "tags", :string
    t.column "start_physical_road_id", :integer
    t.column "end_physical_road_id", :integer
  end

  create_table "junctions", :force => true do |t|
    t.column "objectid", :string
    t.column "created_at", :datetime, :null => false
    t.column "updated_at", :datetime, :null => false
    t.column "geometry", :point, :srid => 4326
    t.column "tags", :string
  end

  add_index "junctions", ["objectid"], :name => "index_junctions_on_objectid"

  create_table "junctions_physical_roads", :id => false, :force => true do |t|
    t.column "physical_road_id", :integer
    t.column "junction_id", :integer
  end

  add_index "junctions_physical_roads", ["junction_id"], :name => "index_junctions_physical_roads_on_junction_id"
  add_index "junctions_physical_roads", ["physical_road_id", "junction_id"], :name => "junctions_physical_roads_ids"

  create_table "logical_roads", :force => true do |t|
    t.column "name", :string
    t.column "objectid", :string
    t.column "created_at", :datetime, :null => false
    t.column "updated_at", :datetime, :null => false
  end

  add_index "logical_roads", ["name"], :name => "index_logical_roads_on_name"
  add_index "logical_roads", ["objectid"], :name => "index_logical_roads_on_objectid"

  create_table "physical_road_conditionnal_costs", :force => true do |t|
    t.column "physical_road_id", :integer
    t.column "cost", :float
    t.column "tags", :string
  end

  create_table "physical_roads", :force => true do |t|
    t.column "objectid", :string
    t.column "logical_road_id", :integer
    t.column "created_at", :datetime, :null => false
    t.column "updated_at", :datetime, :null => false
    t.column "geometry", :line_string, :srid => 4326
    t.column "kind", :string
    t.column "tags", :string
    t.column "length", :integer, :default => 0
    t.column "minimum_width", :integer, :default => 0
  end

  add_index "physical_roads", ["geometry"], :name => "index_physical_roads_on_geometry", :spatial=> true 
  add_index "physical_roads", ["kind"], :name => "index_physical_roads_on_kind"
  add_index "physical_roads", ["logical_road_id"], :name => "index_physical_roads_on_logical_road_id"
  add_index "physical_roads", ["objectid"], :name => "index_physical_roads_on_objectid"

  create_table "street_numbers", :force => true do |t|
    t.column "number", :string
    t.column "location_on_road", :float
    t.column "physical_road_id", :integer
    t.column "created_at", :datetime, :null => false
    t.column "updated_at", :datetime, :null => false
    t.column "geometry", :point, :srid => 4326
    t.column "objectid", :string
  end

  add_index "street_numbers", ["number", "physical_road_id"], :name => "index_street_numbers_on_number_and_physical_road_id"
  add_index "street_numbers", ["physical_road_id"], :name => "index_street_numbers_on_physical_road_id"

end
