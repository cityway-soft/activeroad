# encoding: UTF-8
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
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20141205154841) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"
  enable_extension "hstore"

  create_table "boundaries", force: true do |t|
    t.string  "objectid"
    t.string  "name"
    t.integer "admin_level"
    t.string  "postal_code"
    t.string  "insee_code"
    t.spatial "geometry",    limit: {:srid=>4326, :type=>"multi_polygon"}
  end

  add_index "boundaries", ["geometry"], :name => "index_boundaries_on_geometry", :spatial => true

  create_table "junction_conditionnal_costs", force: true do |t|
    t.integer "junction_id"
    t.float   "cost"
    t.string  "tags"
    t.integer "start_physical_road_id"
    t.integer "end_physical_road_id"
  end

  add_index "junction_conditionnal_costs", ["junction_id"], :name => "index_junction_conditionnal_costs_on_junction_id"

  create_table "junctions", force: true do |t|
    t.string   "objectid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.spatial  "geometry",           limit: {:srid=>4326, :type=>"point"}
    t.hstore   "tags"
    t.float    "height"
    t.float    "waiting_constraint"
  end

  add_index "junctions", ["geometry"], :name => "index_junctions_on_geometry", :spatial => true
  add_index "junctions", ["objectid"], :name => "index_junctions_on_objectid", :unique => true
  add_index "junctions", ["tags"], :name => "junctions_tags"

  create_table "junctions_physical_roads", id: false, force: true do |t|
    t.integer "physical_road_id"
    t.integer "junction_id"
    t.float   "percentage_location"
  end

  add_index "junctions_physical_roads", ["junction_id"], :name => "index_junctions_physical_roads_on_junction_id"
  add_index "junctions_physical_roads", ["physical_road_id", "junction_id"], :name => "junctions_physical_roads_ids", :unique => true
  add_index "junctions_physical_roads", ["physical_road_id"], :name => "index_junctions_physical_roads_on_physical_road_id"

  create_table "logical_roads", force: true do |t|
    t.string   "name"
    t.string   "objectid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "boundary_id"
  end

  add_index "logical_roads", ["boundary_id"], :name => "index_logical_roads_on_boundary_id"
  add_index "logical_roads", ["name"], :name => "index_logical_roads_on_name"
  add_index "logical_roads", ["objectid"], :name => "index_logical_roads_on_objectid", :unique => true

  create_table "physical_road_conditionnal_costs", force: true do |t|
    t.integer "physical_road_id"
    t.float   "cost"
    t.string  "tags"
  end

  add_index "physical_road_conditionnal_costs", ["physical_road_id"], :name => "index_physical_road_conditionnal_costs_on_physical_road_id"

  create_table "physical_roads", force: true do |t|
    t.string   "objectid"
    t.integer  "logical_road_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.spatial  "geometry",            limit: {:srid=>4326, :type=>"line_string"}
    t.hstore   "tags"
    t.string   "minimum_width"
    t.string   "transport_mode"
    t.float    "uphill"
    t.float    "downhill"
    t.string   "slope"
    t.string   "cant"
    t.string   "covering"
    t.integer  "steps_count"
    t.boolean  "banisters_available"
    t.boolean  "tactile_band"
    t.string   "physical_road_type"
    t.boolean  "car"
    t.boolean  "bike"
    t.boolean  "train"
    t.boolean  "pedestrian"
    t.string   "name"
    t.integer  "boundary_id"
    t.integer  "marker",                                                          default: 0
    t.float    "length",                                                          default: 0.0
  end

  add_index "physical_roads", ["boundary_id"], :name => "index_physical_roads_on_boundary_id"
  add_index "physical_roads", ["geometry"], :name => "index_physical_roads_on_geometry", :spatial => true
  add_index "physical_roads", ["logical_road_id"], :name => "index_physical_roads_on_logical_road_id"
  add_index "physical_roads", ["name"], :name => "index_physical_roads_on_name"
  add_index "physical_roads", ["objectid"], :name => "index_physical_roads_on_objectid", :unique => true
  add_index "physical_roads", ["tags"], :name => "physical_roads_tags"

  create_table "street_numbers", force: true do |t|
    t.string   "number"
    t.float    "location_on_road"
    t.integer  "physical_road_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.spatial  "geometry",         limit: {:srid=>4326, :type=>"point"}
    t.string   "objectid"
    t.hstore   "tags"
    t.string   "street"
    t.string   "city"
    t.string   "state"
    t.string   "country"
    t.string   "from_osm_object"
  end

  add_index "street_numbers", ["geometry"], :name => "index_street_numbers_on_geometry", :spatial => true
  add_index "street_numbers", ["number", "physical_road_id"], :name => "index_street_numbers_on_number_and_physical_road_id"
  add_index "street_numbers", ["physical_road_id"], :name => "index_street_numbers_on_physical_road_id"

end
