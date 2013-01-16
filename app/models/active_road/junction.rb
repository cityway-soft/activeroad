module ActiveRoad
  class Junction < ActiveRoad::Base
    attr_accessible :objectid, :tags, :geometry

    validates_uniqueness_of :objectid

    has_and_belongs_to_many :physical_roads, :uniq => true
    has_many :junction_conditionnal_costs

    def location_on_road(road)
      (@location_on_road ||= {})[road.id] ||= road.locate_point(geometry)
    end

    def paths(kind = "road")
      physical_roads.where(:kind => kind).includes(:junctions).collect do |physical_road| 
        ActiveRoad::Path.all self, (physical_road.junctions - [self]), physical_road
      end.flatten
    end

    def access_to_road?(road)
      physical_roads.include? road
    end

    def to_geometry
      geometry
    end

    def to_s
      "#{name} (#{objectid}@#{geometry.to_s})"
    end

    def name
      physical_roads.join(" - ")
    end
  end
end
