module ActiveRoad::RgeoExt
  extend ActiveSupport::Concern
  
  def self.included(base)
    base.class_eval do
      cattr_accessor :geographical_factory, :geos_factory, :cartesian_factory, :ar_connection
      
      self.geos_factory = ::RGeo::Geos.factory(:native_interface => :ffi, :srid => 4326,
                                               :wkt_parser => {:support_ewkt => true, :default_srid => 4326},
                                               :wkt_generator => {:type_format => :ewkt, :emit_ewkt_srid => true},
                                               :wkb_parser => {:support_ewkb => true, :default_srid => 4326},
                                               :wkb_generator => {:type_format => :ewkb, :emit_ewkb_srid => true}
                                               )
      
      self.geographical_factory = ::RGeo::Geographic.spherical_factory(
                                                                       :wkt_parser => {:support_ewkt => true, :default_srid => 4326},
                                                                       :wkt_generator => {:type_format => :ewkt, :emit_ewkt_srid => true},
                                                                       :wkb_parser => {:support_ewkb => true, :default_srid => 4326},
                                                                       :wkb_generator => {:type_format => :ewkb, :emit_ewkb_srid => true})
      
      self.cartesian_factory = ::RGeo::Cartesian.factory( :srid => 4326,
                                               :wkt_parser => {:support_ewkt => true, :default_srid => 4326},
                                               :wkt_generator => {:type_format => :ewkt, :emit_ewkt_srid => true},
                                               :wkb_parser => {:support_ewkb => true, :default_srid => 4326},
                                               :wkb_generator => {:type_format => :ewkb, :emit_ewkb_srid => true})

      self.ar_connection = ActiveRecord::Base.connection
    end
  end

  def self.rgeo_haversine_distance( rgeo_point1, rgeo_point2 )
    self.haversine_distance( rgeo_point1.y, rgeo_point1.x, rgeo_point2.y, rgeo_point2.x )
  end
  
  def self.haversine_distance( lat1, lon1, lat2, lon2 )

    rad_per_deg = Math::PI / 180

    # the great circle distance d will be in whatever units R is in

    rmiles = 3956           # radius of the great circle in miles
    rkm = 6371              # radius in kilometers...some algorithms use 6367
    rfeet = rmiles * 5282   # radius in feet
    rmeters = rkm * 1000    # radius in meters
    
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    
    dlon_rad = dlon * rad_per_deg
    dlat_rad = dlat * rad_per_deg
    
    lat1_rad = lat1 * rad_per_deg
    lon1_rad = lon1 * rad_per_deg
    
    lat2_rad = lat2 * rad_per_deg
    lon2_rad = lon2 * rad_per_deg
    
    # puts "dlon: #{dlon}, dlon_rad: #{dlon_rad}, dlat: #{dlat}, dlat_rad: #{dlat_rad}"
    
    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math.asin( Math.sqrt(a))
    
    dMi = rmiles * c          # delta between the two points in miles
    dKm = rkm * c             # delta in kilometers
    dFeet = rfeet * c         # delta in feet
    dMeters = rmeters * c     # delta in meters
    
    # distances["mi"] = dMi
    # distances["km"] = dKm
    # distances["ft"] = dFeet
    # distances["m"] = dMeters

    return dMeters
  end
  
  module ClassMethods
  end     

end
