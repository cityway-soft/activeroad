module ActiveRoad
  module OsmPbfImporter

    @@pg_batch_size = 10000 # Not Rails.logger.debug a high value because postgres failed to allocate memory
    mattr_reader :pg_batch_size

    @@csv_batch_size = 100000
    mattr_reader :csv_batch_size

    @@relation_required_tags_keys = ["boundary", "admin_level"]
    @@relation_selected_tags_keys = ["boundary", "admin_level", "ref:INSEE", "name", "addr:postcode", "type"]

    mattr_reader :relation_required_tags_keys, :relation_selected_tags_keys    

    @@way_required_tags_keys = ["highway", "railway", "boundary", "admin_level", "addr:housenumber", "addr:interpolation"]
    @@way_for_physical_road_required_tags_keys = ["highway", "railway"]
    @@way_for_boundary_required_tags_keys = ["boundary", "admin_level"]
    @@way_for_street_number_required_tags_keys = ["addr:housenumber"]
    @@way_selected_tags_keys = [ "name", "maxspeed", "oneway", "boundary", "admin_level", "addr:housenumber", "addr:interpolation" ]
    # Add first_node_id and last_node_id
    @@way_optionnal_tags_keys = ["highway", "railway", "maxspeed", "bridge", "tunnel", "toll", "cycleway", "cycleway-right", "cycleway-left", "cycleway-both", "oneway:bicycle", "oneway", "bicycle", "segregated", "foot", "lanes", "lanes:forward", "lanes:forward:bus", "busway:right", "busway:left", "oneway_bus", "boundary", "admin_level", "access", "construction", "junction", "motor_vehicle", "psv", "bus", "addr:city", "addr:country", "addr:state", "addr:street", "addr:interpolation", "footway"]
    mattr_reader :way_required_tags_keys, :way_for_physical_road_required_tags_keys, :way_for_boundary_required_tags_keys, :way_for_street_number_required_tags_keys, :way_selected_tags_keys, :way_optionnal_tags_keys

    @@nodes_selected_tags_keys = [ "addr:housenumber", "addr:city", "addr:postcode", "addr:street" ]
    mattr_reader :nodes_selected_tags_keys

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
    end

    # def extract_tag_value(tag_value)
    #   case tag_value 
    #   when "yes" : 1 
    #   when "no" : 0
    #   when /[0-9].+/i tag_value.to_f        
    #   else 0    
    #   end     
    # end
    
    def save_junctions
      Rails.logger.debug "Begin to save junctions in PostgreSql"
      
      start = Time.now
      junctions_counter = 0
      
      # traverse records by iterator
      junction_columns = ["objectid", "geometry", "created_at", "updated_at"]
      
      CSV.open("#{prefix_path}/junctions.csv", "wb:UTF-8") do |junctions_csv|                
        junctions_csv << junction_columns
        
        nodes_database.each { |key, value|            
          node = Marshal.load(value)            
          
          if node.ways.present? && (node.ways.count >= 2 || node.end_of_way == true )  # Take node with at least two ways or at the end of a way
            junctions_counter += 1
            
            geometry = RgeoExt.geos_factory.point( node.lon, node.lat, 4326) if( node.lon && node.lat )
            junctions_csv << [ node.id, geometry.as_text, Time.now, Time.now ]
          end                   
          
        }
      end
             
      ActiveRoad::Junction.transaction do                                         
        ActiveRoad::Junction.copy_from "#{prefix_path}/junctions.csv"
      end
      
      Rails.logger.info "Finish to backup #{junctions_counter} junctions in PostgreSql in #{display_time(Time.now - start)} seconds"         
    end

    def backup_relations_pgsql
      Rails.logger.info "Begin to backup relations in PostgreSql"
      start = Time.now
      relations_parser = ::PbfParser.new(pbf_file)
      boundaries_counter = 0
      
      # traverse records by iterator
      boundary_columns = ["objectid", "geometry", "name", "admin_level", "postal_code", "insee_code"]     
      
      # Process the file until it finds any relation.
      relations_parser.next until relations_parser.relations.any?
      
      # Once it found at least one relation, iterate to find the remaining relations.
      CSV.open("#{prefix_path}/boundaries.csv", "wb:UTF-8") do |boundary_csv|       
        boundary_csv << boundary_columns

        until relations_parser.relations.empty?
          relations_parser.relations.each do |relation|
            
            if relation.key?(:tags) && required_relation?(relation[:tags])
              tags = selected_tags(relation[:tags], @@relation_selected_tags_keys)
              
              # Use tags["admin_level"] == "8" because catholic boundaries exist!!
              if tags["admin_level"] == "8" && tags["boundary"] == "administrative"
                boundaries_counter += 1
                outer_ways = {}
                inner_ways = {}
                
                begin 
                  relation[:members][:ways].each do |member_way|                  
                    way_data = ways_database[ member_way[:id].to_s ]
                    way = nil
                    nodes = []
                    
                    if way_data.present?
                      way = Marshal.load(way_data)
                      way.nodes.each do |node_id|
                        node = Marshal.load( nodes_database[node_id.to_s] )
                        nodes << node
                      end
                    else
                      raise StandardError, "Geometry error : impossible to find way #{member_way[:id]} for relation #{tags["name"]} with id #{relation[:id]}"                      
                    end
                    
                    if  member_way[:role] == "inner"
                      inner_ways[ member_way[:id] ] = way_geometry(nodes)
                    elsif member_way[:role] == "outer"
                      outer_ways[ member_way[:id] ] = way_geometry(nodes)
                    else # Fix : lot of boundaries have no tags role
                      outer_ways[ member_way[:id] ] = way_geometry(nodes)
                    end
                  end
                  
                  boundary_polygons = extract_relation_polygon(outer_ways.values, inner_ways.values)
                  
                  if boundary_polygons.present?
                    boundary_geometry = RgeoExt.geos_factory.multi_polygon( boundary_polygons ).as_text
                    
                    boundary_csv << [ relation[:id], boundary_geometry, tags["name"], tags["admin_level"], tags["addr:postcode"], tags["ref:INSEE"] ]
                  end
                rescue StandardError => e
                  Rails.logger.error "Geometry error : impossible to build polygon for relation #{tags["name"]} with id #{relation[:id]} : #{e.message}"
                end
              end
            end
          end
          
          # When there's no more fileblocks to parse, #next returns false
          # This avoids an infinit loop when the last fileblock still contains relations
          break unless relations_parser.next                 
        end
      end
      
      ActiveRoad::Boundary.transaction do                                         
        ActiveRoad::Boundary.copy_from "#{prefix_path}/boundaries.csv"
      end
      
      Rails.logger.info  "Finish to backup #{boundaries_counter} boundaries in PostgreSql  in #{display_time(Time.now - start)} seconds"
    end

    def save_physical_roads
      Rails.logger.info "Begin to save physical_roads in PostgreSql"
      start = Time.now
   
      ways_counter = 0

      # traverse records by iterator
      physical_road_columns = ["objectid", "car", "bike", "train", "pedestrian", "name", "geometry", "length", "boundary_id", "tags", "created_at", "updated_at"]
      
      CSV.open("#{prefix_path}/physical_roads.csv", "wb:UTF-8") do |physical_roads_csv|
        physical_roads_csv << physical_road_columns
          
        ways_database.each { |key, value|          
          way = Marshal.load(value)
          
          if way.options["highway"].present? || way.options["railway"].present? # Use ways with tags highway or railway
            ways_counter += 1
            
            nodes = []
            way.nodes.each_with_index do |node_id, index|
              node = Marshal.load( nodes_database[node_id.to_s] )
              nodes << node                
            end
            way_geometry = way_geometry(nodes)
            way_length = way_length(way_geometry)
            
            way_boundary = way.boundary.present? ? way.boundary.to_i : nil
            physical_roads_csv << [ way.id, way.car, way.bike, way.train, way.pedestrian, way.name, way_geometry.as_text, way_length, way_boundary, "#{way.options.to_s.gsub(/[{}]/, '')}", Time.now, Time.now ]
          end
        }
      end
      
      # Save physical roads
      ActiveRoad::PhysicalRoad.transaction do                                         
        ActiveRoad::PhysicalRoad.copy_from "#{prefix_path}/physical_roads.csv"
      end

      Rails.logger.info "Finish to save #{ways_counter} physical_roads in PostgreSql in #{display_time(Time.now - start)} seconds"
    end

    def way_geometry(nodes)
      if nodes.present? &&  1 < nodes.count
        wkt_geometry = "LINESTRING("
        last_node = nodes.last
        nodes.each do |node|
          wkt_geometry += "#{node.lon} #{node.lat}"
          wkt_geometry += ", " if node != last_node 
        end
        wkt_geometry += ")"

        RgeoExt.geos_factory.parse_wkt(wkt_geometry)
      end
    end

    def way_length(way_geometry)
      if way_geometry
        RgeoExt.geographical_factory.line_string(way_geometry.points).length
      else
        0
      end
    end

    def save_physical_road_conditionnal_costs_and_junctions
      Rails.logger.info "Begin to backup ways in PostgreSql"
      
      start = Time.now
      physical_road_conditionnal_costs_counter = junctions_physical_roads_counter = 0
      physical_road_conditionnal_cost_columns = ["tags", "cost", "physical_road_id"]
      junction_physical_road_columns = ["physical_road_id", "junction_id"]
      
      CSV.open("#{prefix_path}/physical_road_conditionnal_costs.csv", "wb:UTF-8") do |physical_road_conditionnal_costs_csv|
        CSV.open("#{prefix_path}/junctions_physical_roads.csv", "wb:UTF-8") do |junctions_physical_roads_csv|
          physical_road_conditionnal_costs_csv << physical_road_conditionnal_cost_columns
          junctions_physical_roads_csv << junction_physical_road_columns
          
          ways_database.each { |key, value|
            way = Marshal.load(value)

            if way.options["highway"].present? || way.options["railway"].present? # Use ways with tags highway or railway
              way_conditionnal_costs = physical_road_conditionnal_costs(way)
              way_conditionnal_costs.each do |way_conditionnal_cost|
                physical_road_conditionnal_costs_counter += 1
                physical_road_conditionnal_costs_csv << way_conditionnal_cost + [ physical_roads_database[way.id] ]
              end

              way.nodes.uniq.each do |node_id|
                junction_id = junctions_database[node_id]
                junctions_physical_roads_counter += 1
                junctions_physical_roads_csv << [ physical_roads_database[way.id], junction_id ] if junction_id.present?
              end
            end
          }
        end
      end
      
      # Save physical road conditionnal costs
      ActiveRoad::PhysicalRoadConditionnalCost.transaction do                                         
        ActiveRoad::PhysicalRoadConditionnalCost.copy_from "#{prefix_path}/physical_road_conditionnal_costs.csv"
      end

      # Save physical road and junctions link
      ActiveRoad::JunctionsPhysicalRoad.transaction do                                         
        ActiveRoad::JunctionsPhysicalRoad.copy_from "#{prefix_path}/junctions_physical_roads.csv"
      end

      Rails.logger.info "Finish to backup #{junctions_physical_roads_counter} junctions_physical_roads and #{physical_road_conditionnal_costs_counter} physical_road_conditionnal_costs in PostgreSql in #{display_time(Time.now - start)} seconds"
    end

    def save_street_numbers_from_nodes

      Rails.logger.debug "Begin to save street_numbers in PostgreSql"
      
      start = Time.now
      street_numbers_counter = 0
      
      # traverse records by iterator
      street_number_columns = ["objectid", "geometry", "number", "street", "city", "state", "country", "location_on_road", "physical_road_id", "from_osm_object", "tags", "created_at", "updated_at"]
      
      CSV.open("#{prefix_path}/street_numbers.csv", "wb:UTF-8") do |street_numbers_csv|                  
        street_numbers_csv << street_number_columns
        
        nodes_database.each { |key, value|            
          node = Marshal.load(value)          

          if node.addr_housenumber.present? && node.from_osm_object != "way_address" # Import only street numbers contain in node and not in address interpolation 
            street_numbers_counter += 1
            
            geometry = RgeoExt.geos_factory.point( node.lon, node.lat, 4326) if( node.lon && node.lat )
            physical_road = ActiveRoad::StreetNumber.computed_linked_road(geometry, node.tags["addr:street"])
            physical_road_id = physical_road.present? ? physical_road.id : nil
            location_on_road = physical_road_id.present? ? ActiveRoad::StreetNumber.computed_location_on_road(physical_road.geometry, geometry) : nil
            
            street_numbers_csv << [ node.id, geometry.as_text, node.addr_housenumber, node.tags["addr:street"], node.tags["addr:city"], node.tags["addr:state"], node.tags["addr:country"], location_on_road, physical_road_id, node.from_osm_object, "#{node.tags.to_s.gsub(/[{}]/, '')}", Time.now, Time.now ]
          end
          
        }
      end
      
      ActiveRoad::StreetNumber.transaction do
        ActiveRoad::StreetNumber.copy_from "#{prefix_path}/street_numbers.csv"
      end
      
      Rails.logger.info "Finish to save #{street_numbers_counter} street numbers in PostgreSql in #{display_time(Time.now - start)} seconds"         
      
    end

    def save_street_numbers_from_ways
      Rails.logger.info "Begin to save street_numbers from ways in PostgreSql"
      start = Time.now
   
      street_numbers_counter = 0

      # traverse records by iterator
      street_number_columns = ["objectid", "geometry", "number", "street", "city", "state", "country", "location_on_road", "physical_road_id", "from_osm_object", "tags", "created_at", "updated_at"]
      
      CSV.open("#{prefix_path}/street_numbers2.csv", "wb:UTF-8") do |street_numbers_csv|          
        street_numbers_csv << street_number_columns
        
        ways_database.each { |key, value|          
          way = Marshal.load(value)

          if way.addr_housenumber.present? || way.addr_interpolation.present?            
            nodes = []
            way.nodes.each_with_index do |node_id, index|
              node = Marshal.load( nodes_database[node_id.to_s] )
              nodes << node                
            end
            way_geometry = way_geometry(nodes)
            
            if way.addr_housenumber.present?            
              street_numbers_counter += 1
              geometry = way_geometry.envelope.centroid
              
              physical_road = ActiveRoad::StreetNumber.computed_linked_road(geometry, way.options["addr:street"])
              physical_road_id = physical_road.present? ? physical_road.id : nil
              location_on_road = physical_road_id.present? ? ActiveRoad::StreetNumber.computed_location_on_road(physical_road.geometry, geometry) : nil
              
              street_numbers_csv << [ way.id, geometry.as_text, way.addr_housenumber, way.options["addr:street"], way.options["addr:city"], way.options["addr:state"], way.options["addr:country"], location_on_road, physical_road_id, "way_building", "#{way.options.to_s.gsub(/[{}]/, '')}", Time.now, Time.now ]
            elsif way.addr_interpolation.present?   # If ways with address interpolation
              if way_geometry.present? #and geometry is a linestring              
                # Get the first name of the extremities nodes
                way_name = [nodes.first.tags["addr:street"], nodes.last.tags["addr:street"]].compact.first

                # Find the closest physical road from the middle of the way geometry
                physical_road = ActiveRoad::PhysicalRoad.joins( "JOIN ( SELECT ST_LineInterpolatePoint('#{ way_geometry}', 0.5 ) geometry ) p ON ST_DWithin( physical_roads.geometry, p.geometry, 0.0011)").where("name = ?", way_name).order("ST_Distance(p.geometry, physical_roads.geometry)").first if way_name.present?
                physical_road = ActiveRoad::PhysicalRoad.joins( "JOIN ( SELECT ST_LineInterpolatePoint('#{ way_geometry}', 0.5 ) geometry ) p ON ST_DWithin( physical_roads.geometry, p.geometry, 0.0011)").order("ST_Distance(p.geometry, physical_roads.geometry)").first if physical_road.blank?
                
                physical_road_id = physical_road.present? ? physical_road.id : nil
                
                # Link extremities node to the physical road previously founded
                [nodes.first, nodes.last] .each do |node|
                  geometry = RgeoExt.geos_factory.point( node.lon, node.lat, 4326) if( node.lon && node.lat )
                  location_on_road = physical_road_id.present? ? ActiveRoad::StreetNumber.computed_location_on_road(physical_road.geometry, geometry) : nil

                  if node.addr_housenumber.present?
                    street_numbers_counter += 1
                    street_numbers_csv << [ node.id, geometry.as_text, node.addr_housenumber, node.tags["addr:street"], node.tags["addr:city"], node.tags["addr:state"], node.tags["addr:country"], location_on_road, physical_road_id, node.from_osm_object, "#{node.tags.to_s.gsub(/[{}]/, '')}", Time.now, Time.now ]
                  end
                end
              else
                Rails.logger.error("Way for street number is rejected because it hasn't got a linestring geometry #{way.inspect}")
              end
            end
          end
        }
      end     
      
      ActiveRoad::StreetNumber.transaction do                                         
        ActiveRoad::StreetNumber.copy_from "#{prefix_path}/street_numbers2.csv"        
      end

      Rails.logger.info "Finish to save #{street_numbers_counter} street numbers from ways in PostgreSql in #{display_time(Time.now - start)} seconds"
    end

    def physical_road_conditionnal_costs(way)
      [].tap do |prcc|        
        prcc << [ "car", Float::MAX] if !way.car
        prcc << [ "pedestrian", Float::MAX] if !way.pedestrian
        prcc << [ "bike", Float::MAX] if !way.bike
        prcc << [ "train", Float::MAX] if !way.train
      end
    end
    
    def split_way_with_boundaries
      Rails.logger.info "Begin to split and affect boundaries to ways in PostgreSql"
      start = Time.now

      # Update physical roads entirely contains in boundaries
      ActiveRoad::PhysicalRoad.connection.select_all("SELECT physical_road.id AS physical_road_id, boundary.id AS boundary_id FROM physical_roads physical_road, boundaries boundary WHERE ST_Covers( boundary.geometry, physical_road.geometry)").each_slice(@@pg_batch_size) do |group|
        ActiveRoad::PhysicalRoad.transaction do 
          group.each do |element|
            ActiveRoad::PhysicalRoad.update(element["physical_road_id"], :boundary_id => element["boundary_id"])
          end
        end
      end

      simple_ways = []
      simple_ways_not_line_string = 0

      # Fix : Produce 2 ways when way is tangent to boundary borders for each boundary
      # Get geometries in boundary      
      sql = "SELECT b.id AS boundary_id, p.id AS physical_road_id, p.objectid AS physical_road_objectid, p.tags AS physical_road_tags, ST_AsText(p.geometry) AS physical_road_geometry, 
j1.objectid AS departure_objectid, ST_AsText(j1.geometry) AS departure_geometry, 
j2.objectid AS arrival_objectid, ST_AsText(j2.geometry) AS arrival_geometry, 
ST_AsText( (ST_Dump(ST_Intersection( p.geometry , b.geometry))).geom ) AS intersection_geometry 
FROM physical_roads p, boundaries b, junctions j1, junctions j2, junctions_physical_roads jp, junctions_physical_roads jp2 
WHERE p.boundary_id IS NULL AND ST_Crosses( b.geometry, p.geometry)
AND j1.id = jp.junction_id AND p.id = jp.physical_road_id AND ST_Equals(ST_StartPoint(p.geometry), j1.geometry)
AND j2.id = jp2.junction_id AND p.id = jp2.physical_road_id AND ST_Equals(ST_EndPoint(p.geometry), j2.geometry)".gsub(/^( |\t)+/, "")      
      ActiveRoad::PhysicalRoad.connection.select_all( sql ).each do |result|
        intersection_geometry = RgeoExt.geos_factory.parse_wkt("#{result['intersection_geometry']}")

        # Not take in consideration point intersection!!
        if RGeo::Feature::LineString === intersection_geometry
          simple_way = SimpleWay.new(result["boundary_id"], result["physical_road_id"], result["physical_road_objectid"], result["physical_road_tags"], RgeoExt.geos_factory.parse_wkt("#{result['physical_road_geometry']}"), result["departure_objectid"], RgeoExt.geos_factory.parse_wkt("#{result['departure_geometry']}"), result["arrival_objectid"], RgeoExt.geos_factory.parse_wkt("#{result['arrival_geometry']}"), intersection_geometry )
          # Delete boucle line string Ex : 9938647-4
          simple_ways << simple_way if simple_way.departure != simple_way.arrival
        else
          simple_ways_not_line_string += 1
        end
      end
      
      # Get geometries not in boundaries      
      sql = "SELECT ST_AsText( (ST_Dump(difference_geometry)).geom ) AS difference_geometry, v.id AS physical_road_id, v.objectid AS physical_road_objectid, v.tags AS physical_road_tags, ST_AsText(v.geometry) AS physical_road_geometry,
j1.objectid AS departure_objectid, ST_AsText(j1.geometry) AS departure_geometry, 
j2.objectid AS arrival_objectid, ST_AsText(j2.geometry) AS arrival_geometry
FROM 
( SELECT pr.id, pr.objectid, pr.tags, pr.geometry, pr.boundary_id, ST_Difference( pr.geometry, ST_Union( b.geometry)) as difference_geometry 
FROM physical_roads pr, boundaries b 
WHERE pr.boundary_id IS NULL AND ST_Crosses( b.geometry, pr.geometry)
GROUP BY pr.id, pr.geometry) v, 
junctions j1, junctions j2, junctions_physical_roads jp, junctions_physical_roads jp2
WHERE j1.id = jp.junction_id AND v.id = jp.physical_road_id AND ST_Equals(ST_StartPoint(v.geometry), j1.geometry)
AND j2.id = jp2.junction_id AND v.id = jp2.physical_road_id AND ST_Equals(ST_EndPoint(v.geometry), j2.geometry)
AND NOT ST_IsEmpty(difference_geometry)".gsub(/^( |\t)+/, "") 
      ActiveRoad::PhysicalRoad.connection.select_all( sql ).each do |result|
        difference_geometry = RgeoExt.geos_factory.parse_wkt("#{result['difference_geometry']}")
        if RGeo::Feature::LineString === difference_geometry
          simple_way = SimpleWay.new(nil, result["physical_road_id"], result["physical_road_objectid"], result["physical_road_tags"], RgeoExt.geos_factory.parse_wkt("#{result['physical_road_geometry']}"), result["departure_objectid"], RgeoExt.geos_factory.parse_wkt("#{result['departure_geometry']}"), result["arrival_objectid"], RgeoExt.geos_factory.parse_wkt("#{result['arrival_geometry']}"), difference_geometry )
          # Delete boucle line string Ex : 9938647-4
          simple_ways << simple_way if simple_way.departure != simple_way.arrival
        else
          simple_ways_not_line_string += 1
        end
      end
      
      # Prepare reordering ways         
      simple_ways_by_old_physical_road_id = simple_ways.group_by{|sw| sw.old_physical_road_id}

      # Hack : in the code we take the first one which has an intersection point and it deletes
      # dual segment tangent on the boundary borders 
      simple_ways_by_old_physical_road_id.each do |old_physical_road_id, ways|
        ways.each do |way|
          if way.departure == way.old_departure_geometry
            way.departure_objectid = way.old_departure_objectid
            way.previous = nil
          else
            way.departure_objectid = way.default_departure_objectid
            way.previous = ways.detect{ |select_way| select_way.arrival == way.departure }
          end
          
          if way.arrival == way.old_arrival_geometry
            way.arrival_objectid = way.old_arrival_objectid
            way.next = nil 
          else
            way.arrival_objectid = way.default_arrival_objectid
            way.next = ways.detect{ |select_way| select_way.departure == way.arrival }
          end          
        end
      end
      
      # Save new ways and junctions
      #physical_roads ||= ActiveRoad::PhysicalRoad.where(:objectid => simple_ways_by_old_physical_road_id.keys).includes(:conditionnal_costs)
      
      simple_ways_by_old_physical_road_id.each_slice(1000) { |group|
        ActiveRoad::PhysicalRoad.transaction do            
          
          group.each do |old_physical_road_id, ways|
            #puts ways.sort.inspect             
            next_way = ways.detect{ |select_way| select_way.previous == nil }
            way_counter = 0
            junction_counter = 0

            
            while next_way != nil
              start = Time.now

              #old_physical_road = physical_roads.where(:id => old_physical_road_id)               
              #physical_road.conditionnal_costs = old_physical_road.conditionnal_costs

              # Create departure
              if next_way.previous != nil
                departure = ActiveRoad::Junction.where(:objectid => "#{next_way.departure_objectid}-#{junction_counter}").first_or_create( :geometry => next_way.departure )
                junction_counter += 1
              else
                departure = ActiveRoad::Junction.find_by_objectid(next_way.departure_objectid) 
              end
              
              # Create arrival
              if next_way.next != nil
                arrival = ActiveRoad::Junction.where(:objectid => "#{next_way.arrival_objectid}-#{junction_counter}").first_or_create( :geometry => next_way.arrival )
              else
                arrival = ActiveRoad::Junction.find_by_objectid(next_way.arrival_objectid)
              end

              old_physical_road_tags = next_way.old_physical_road_tags_hash
              old_physical_road_tags["first_node_id"] = departure.objectid
              old_physical_road_tags["last_node_id"] =  arrival.objectid 
              
              physical_road = ActiveRoad::PhysicalRoad.create! :objectid => "#{next_way.old_physical_road_objectid}-#{way_counter}", :boundary_id => next_way.boundary_id, :geometry => next_way.geometry, :tags => old_physical_road_tags
              
              # Add departure and arrival to physical road
              physical_road.junctions << [departure, arrival]

              way_counter += 1

              if way_counter > ways.size
                Rails.logger.error "Infinite boucle when save physical road splitted with boundaries"
                raise Exception.new "Infinite boucle when save physical road splitted with boundaries"
              end
              
              next_way = next_way.next                                
            end
            
          end
        end
      }
      
      # Delete old ways
      ActiveRoad::PhysicalRoad.destroy(simple_ways_by_old_physical_road_id.keys)
      
      Rails.logger.info "Finish to split and affect boundaries to ways in PostgreSql in #{display_time(Time.now - start)} seconds"
    end

    class SimpleWay
      include Comparable
      attr_accessor :boundary_id, :old_physical_road_id, :old_physical_road_objectid, :old_physical_road_tags, :old_physical_road_geometry, :old_departure_objectid, :old_departure_geometry, :old_arrival_objectid, :old_arrival_geometry, :departure_objectid, :arrival_objectid, :geometry, :next, :previous
        
      def initialize(boundary_id, old_physical_road_id, old_physical_road_objectid, old_physical_road_tags, old_physical_road_geometry, old_departure_objectid, old_departure_geometry, old_arrival_objectid, old_arrival_geometry, geometry)
        @boundary_id = boundary_id
        @old_physical_road_id = old_physical_road_id
        @old_physical_road_objectid = old_physical_road_objectid
        @old_physical_road_tags = old_physical_road_tags || ""
        @old_physical_road_geometry = old_physical_road_geometry
        @old_departure_objectid = old_departure_objectid
        @old_departure_geometry = old_departure_geometry
        @old_arrival_objectid = old_arrival_objectid
        @old_arrival_geometry = old_arrival_geometry
        @geometry = geometry       
      end

      def old_physical_road_tags_hash
        #Fix tags build from string
        tags = {}.tap do |tags| 
          old_physical_road_tags.split(',').each do |pair|                    
            key, value = pair.split("=>")
            tags[key.gsub(/\W/, "")] = value.gsub(/\W/, "")
          end
        end
      end
      
      def departure
        #puts "geometry class #{geometry.class}, value #{geometry.inspect}"
        geometry.points.first if geometry
      end

      def arrival
        geometry.points.last if geometry
      end      
      
      def default_departure_objectid
        "#{old_departure_objectid}-#{old_arrival_objectid}"
      end
      
      def default_arrival_objectid
        "#{old_departure_objectid}-#{old_arrival_objectid}"
      end

      def <=>(another)
        # puts "self : #{self.departure.inspect}, #{self.arrival.inspect}"
        # puts "another : #{another.departure.inspect}, #{another.arrival.inspect}"
        # puts old_physical_road_geometry.points.inspect
        # puts old_physical_road_geometry.points.index(another.arrival).inspect
        # puts old_physical_road_geometry.points.index(self.departure).inspect
        if self.departure == another.arrival || old_physical_road_geometry.points.index(another.arrival) < old_physical_road_geometry.points.index(self.departure)         
          1
        elsif self.arrival == another.departure || old_physical_road_geometry.points.index(self.arrival) < old_physical_road_geometry.points.index(another.departure)
          -1
        else
          nil
        end
      end
      
    end

    def extract_relation_polygon(outer_geometries, inner_geometries = [])
      outer_rings = join_ways(outer_geometries)
      inner_rings = join_ways(inner_geometries)

      # TODO : Fix the case where many outer rings with many inner rings
      polygons = [].tap do |polygons|
        outer_rings.each { |outer_ring|
          polygons << RgeoExt.geos_factory.polygon( outer_ring, inner_rings )
        }
      end
    end

    def join_ways(ways)
      closed_ways = []
      endpoints_to_ways = EndpointToWayMap.new
      for way in ways
        if way.is_closed?
          closed_ways << way
          next
        end

        # Are there any existing ways we can join this to?
        to_join_to = endpoints_to_ways.get_from_either_end(way)
        if to_join_to.present?
          joined = way
          for existing_way in to_join_to
            joined = join_way(joined, existing_way)
            endpoints_to_ways.remove_way(existing_way)
            if joined.is_closed?
              closed_ways << joined
              break
            end
          end

          if !joined.is_closed?
            endpoints_to_ways.add_way(joined)
          end
        else
          endpoints_to_ways.add_way(way)
        end
      end

      if endpoints_to_ways.number_of_endpoints != 0
        raise StandardError, "Unclosed boundaries"
      end

      closed_ways
    end

    def join_way(way, other)
      if way.is_closed?
        raise StandardError, "Trying to join a closed way to another"
      end
      if other.is_closed?
        raise StandardError, "Trying to join a way to a closed way"
      end

      if way.points.first == other.points.first
        new_points = other.points.reverse[0..-2] + way.points
      elsif way.points.first == other.points.last
        new_points = other.points[0..-2] + way.points
      elsif way.points.last == other.points.first
        new_points = way.points[0..-2] + other.points
      elsif way.points.last == other.points.last
        new_points = way.points[0..-2] + other.points.reverse
      else
        raise StandardError, "Trying to join two ways with no end point in common"
      end

      RgeoExt.geos_factory.line_string(new_points)
    end

    class EndpointToWayMap
      attr_accessor :endpoints

      def initialize
        @endpoints = {}
      end

      def add_way(way)
        if get_from_either_end(way).present?
          raise StandardError, "Call to add_way would overwrite existing way(s)"
        end
        self.endpoints[way.points.first] = way
        self.endpoints[way.points.last] = way
      end

      def remove_way(way)
        endpoints.delete(way.points.first)
        endpoints.delete(way.points.last)
      end

      def get_from_either_end(way)
        [].tap do |selected_end_points|
          selected_end_points << endpoints[way.points.first] if endpoints.include?(way.points.first)
          selected_end_points << endpoints[way.points.last] if endpoints.include?(way.points.last)
        end
      end

      def number_of_endpoints
        return endpoints.size
      end

    end

    def backup_logical_roads_pgsql
      Rails.logger.info "Begin to backup logical roads in PostgreSql"
      start = Time.now
      logical_roads_counter = 0

      saved_name = nil
      saved_boundary = nil
      saved_logical_road = nil
      ActiveRoad::PhysicalRoad.where("physical_roads.name IS NOT NULL OR physical_roads.boundary_id IS NOT NULL").select("name,boundary_id,id").order(:boundary_id,:name).find_in_batches(batch_size: 2000) do |group|
        ActiveRoad::LogicalRoad.transaction do
          group.each do |physical_road|
            not_same_name = (saved_name != physical_road.name)
            not_same_boundary = (saved_boundary != physical_road.boundary_id)
            
            saved_name = physical_road.name if not_same_name
            saved_boundary = physical_road.boundary_id if not_same_boundary

            if not_same_name || not_same_boundary
              logical_roads_counter += 1
              saved_logical_road = ActiveRoad::LogicalRoad.create(:name => saved_name, :boundary_id => saved_boundary)
            end
            
            physical_road.update_column(:logical_road_id, saved_logical_road.id) if saved_logical_road.present?
          end
        end
      end
            
      Rails.logger.info "Finish to backup #{logical_roads_counter} logical roads in PostgreSql in #{ display_time(Time.now - start)} seconds"
    end

  end
end
