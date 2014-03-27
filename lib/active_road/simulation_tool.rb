class ActiveRoad::SimulationTool
    def self.sql_insert_junction( x, y)
        x = (( x * 100000 ).to_i)/100000.0
        y = (( y * 100000 ).to_i)/100000.0
        "INSERT INTO junctions (objectid, created_at, updated_at, geometry) values ( '#{x}-#{y}', '2014-03-14 14:32:23.362164', '2014-03-14 14:32:23.362164', ST_geometryFromText('POINT( #{x} #{y})', 4326) );"
    end
    def self.sql_insert_physical_road( x1, y1, x2, y2)
        x2 = (( x2 * 100000 ).to_i)/100000.0
        y2 = (( y2 * 100000 ).to_i)/100000.0
        x1 = (( x1 * 100000 ).to_i)/100000.0
        y1 = (( y1 * 100000 ).to_i)/100000.0
        "INSERT INTO physical_roads (objectid, created_at, updated_at, geometry) values ( '#{x1}-#{y1}-#{x2}-#{y2}', '2014-03-14 14:32:23.362164', '2014-03-14 14:32:23.362164', ST_geometryFromText('LINESTRING( #{x1} #{y1}, #{x2} #{y2})', 4326) );"
    end
    def self.save_simulated_square( size )
        ActiveRoad::PhysicalRoad.connection.execute square_sqls( size ).join("\n")
        ActiveRoad::PhysicalRoad.connection.execute relation_sqls.join("\n")
    end


    def self.square_sqls( size)
        result = []
        step = (1.0 / size)
        index_x = 0
        0.upto( size) do |i_x|
            index_y = 0
            0.upto( size) do |i_y|
                result << sql_insert_junction( index_x, index_y)

                if i_y < size
                    result << sql_insert_physical_road( index_x, index_y, index_x, index_y+step)
                end
                if i_x < size
                    result << sql_insert_physical_road( index_x, index_y, index_x+step, index_y)
                end
                index_y += step
            end
            index_x += step
        end
        result
    end


    def self.j_by_objectid
        hash = {}
        ActiveRoad::Junction.all.each do |j|
            hash[ j.objectid ] = j.id
        end
        hash
    end
    def self.pr_by_objectid
        hash = {}
        ActiveRoad::PhysicalRoad.all.each do |pr|
            hash[ pr.objectid ] = pr.id
        end
        hash
    end
    def self.relation_sqls
        result = []
        pr_h = pr_by_objectid
        j_h = j_by_objectid
        pr_h.keys.each do |pr_objectid|
            parts = pr_objectid.split("-")
            j_start_objectid = "#{parts[0]}-#{parts[1]}"
            j_end_objectid = "#{parts[2]}-#{parts[3]}"

            result << "INSERT INTO junctions_physical_roads ( physical_road_id, junction_id ) values ( #{pr_h[ pr_objectid ]}, #{j_h[ j_start_objectid ]} );"
            result << "INSERT INTO junctions_physical_roads ( physical_road_id, junction_id ) values ( #{pr_h[ pr_objectid ]}, #{j_h[ j_end_objectid ]} );"
        end
        result
    end


end
