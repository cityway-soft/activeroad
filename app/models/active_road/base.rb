class ActiveRoad::Base < ActiveRecord::Base
  self.abstract_class = true

  # By default, use the GEOS implementation for spatial columns.
  self.rgeo_factory_generator = ::RGeo::Geos.factory_generator(:srid => ActiveRoad.srid, :native_interface => :ffi, :wkt_parser => {:support_ewkt => true})

  # By default, use the GEOS implementation for spatial columns.
  def self.rgeo_factory
    ::RGeo::Geos.factory(:srid => ActiveRoad.srid, :native_interface => :ffi, :wkt_parser => {:support_ewkt => true})   
  end

  establish_connection :roads if configurations["roads"].present?
end
