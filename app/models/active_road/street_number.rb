module ActiveRoad
  class StreetNumber < ActiveRoad::Base
    acts_as_copy_target
    store_accessor :tags
    #attr_accessible :objectid, :tags, :number, :geometry, :physical_road_id, :location_on_road
    set_rgeo_factory_for_column(:geometry, @@geos_factory)
    
    validates_uniqueness_of :objectid
    validates_presence_of :number, :stored_geometry

    belongs_to :physical_road, :class_name => "ActiveRoad::PhysicalRoad"



    def road
      @road or physical_road
    end
    
    def road=(road)
      @road ||= road
    end        

    def self.computed_linked_road(street_number_geometry, street_number_street = "")
      estimated_linked_road = ActiveRoad::PhysicalRoad.where("name = ? AND ST_DWithin(geometry, '#{street_number_geometry}', 0.0011)", street_number_street).first if street_number_street.present?

      estimated_linked_road = ActiveRoad::PhysicalRoad.where( "ST_DWithin(geometry, '#{street_number_geometry}', 0.0011)").first if estimated_linked_road.blank?
      
      estimated_linked_road if estimated_linked_road.present?
    end

    def self.computed_location_on_road(road_geometry, street_number_geometry)
      ActiveRecord::Base.connection.execute("SELECT ST_Line_Locate_Point('#{road_geometry}','#{street_number_geometry}') AS location")[0]["location"]
    end
    
    def computed_linked_road
      estimated_linked_road = ActiveRoad::PhysicalRoad.where("name = '#{self.street}' AND ST_DWithin(geometry, '#{self.geometry}', 0.0011)").first if self.street.present?

      estimated_linked_road = ActiveRoad::PhysicalRoad.where( "ST_DWithin(geometry, '#{self.geometry}', 0.0011)").first if estimated_linked_road.blank?
      
      estimated_linked_road if estimated_linked_road.present?
      self.physical_road = estimated_linked_road
    end

    def computed_location_on_road
      if stored_location_on_road.nil? and stored_geometry
        self.location_on_road = ActiveRecord::Base.connection.execute("SELECT ST_Line_Locate_Point('#{road.geometry}','#{stored_geometry}') AS location")[0]["location"]
      end
    end
    
    def stored_geometry
      read_attribute :geometry
    end

    def geometry
      stored_geometry or computed_geometry
    end

    def computed_geometry
      road.at estimated_location_on_road
    end

    def location_on_road
      stored_location_on_road or estimated_location_on_road
    end

    def stored_location_on_road
      read_attribute :location_on_road
    end   

    def estimated_location_on_road
      if previous and self.next
        number_ratio = (number.to_i - previous.number.to_i) / (self.next.number.to_i - previous.number.to_i).to_f
        previous.location_on_road + number_ratio * (self.next.location_on_road - previous.location_on_road)
      end
    end

    def previous
      @previous ||= road.numbers.where("number < ?", number).order("number desc").first
    end

    def next
      @next ||= road.numbers.where("number > ?", number).order("number").first
    end

    def odd?
      number.to_i.odd?
    end

    def even?
      number.to_i.even?
    end
    
    def number
      Number.new read_attribute(:number)
    end

    class Number < String

      alias_method :numeric_value, :to_i

      def suffix
        gsub(/^[0-9]+/,'')
      end

      def +(value)
        self.class.new "#{numeric_value+value}#{suffix}"
      end

      def -(value)
        self.class.new "#{numeric_value-value}#{suffix}"
      end

    end

  end
end
