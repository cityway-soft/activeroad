module ActiveRoad
  class AccessLink
    include RgeoExt::Support
    attr_accessor :departure, :arrival

    def initialize(attributes = {})
      attributes.each do |k, v|
        send("#{k}=", v)
      end
    end

    def name
      "AccessLink : #{departure} -> #{arrival}"
    end

    alias_method :to_s, :name

    def self.from(location)
      ActiveRoad::AccessPoint.from(location).collect do |access_point|
        new :departure => location, :arrival => access_point
      end
    end

    def departure_geometry
      @departure_geometry ||= RGeo::Feature::Point === departure ? departure : departure.geometry 
    end

    def arrival_geometry
      @arrival_geometry ||= RGeo::Feature::Point === arrival ? arrival : arrival.geometry
    end
    
    def length
      @length ||= geometry.length
    end

    def geometry
      @geometry ||= RgeoExt.cartesian_factory.line_string( [departure_geometry, arrival_geometry] )
    end

    delegate :access_to_road?, :to => :arrival

    def paths
      arrival.respond_to?(:paths) ? arrival.paths : [arrival]
    end

    def access_to_road?(road)
      arrival.respond_to?(:access_to_road?) ? arrival.access_to_road?(road) : false
    end

  end
end
