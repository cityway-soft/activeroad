class ActiveRoad::Base < ActiveRecord::Base
  # In order to make ActiveRecord models play nice with DJ and Apartment, include Apartment::Delayed::Requirements in any model that is being serialized by DJ
  include Apartment::Delayed::Requirements

  self.abstract_class = true

  # By default, use the GEOS implementation for spatial columns.
  self.rgeo_factory_generator = ::RGeo::Geos.factory_generator(:srid => ActiveRoad.srid, :native_interface => :ffi, :wkt_parser => {:support_ewkt => true})

  # By default, use the GEOS implementation for spatial columns.
  def self.rgeo_factory
    ::RGeo::Geos.factory(:srid => ActiveRoad.srid, :native_interface => :ffi, :wkt_parser => {:support_ewkt => true})   
  end

  establish_connection :roads if configurations["roads"].present?
end
