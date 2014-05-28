  def geos_factory
    ::RGeo::Geos.factory(:native_interface => :ffi, :srid => 4326,
                         :wkt_parser => {:support_ewkt => true, :default_srid => 4326},
                         :wkt_generator => {:type_format => :ewkt, :emit_ewkt_srid => true},
                         :wkb_parser => {:support_ewkb => true, :default_srid => 4326},
                         :wkb_generator => {:type_format => :ewkb, :emit_ewkb_srid => true}
                         )
  end

  def geographical_factory
    ::RGeo::Geographic.spherical_factory
  end

  def cartesian_factory
    ::RGeo::Cartesian.factory()
  end

# def geometry_from_text(text, srid = 4326)
#   GeoRuby::SimpleFeatures::Geometry.from_ewkt "SRID=#{srid};#{text}"
# end

# def point(x=0.0, y=0.0, srid = 4326)
#   GeoRuby::SimpleFeatures::Point.from_x_y x, y, srid
# end

# def line_string(*points)
#   if points.one? and String === points.first
#      geometry_from_text("LINESTRING(#{points.first})")
#   else
#     GeoRuby::SimpleFeatures::LineString.from_points(points, points.first.srid)
#   end
# end

# def linear_ring(*points)
#   if points.one? and String === points.first
#     geometry_from_text("LINESTRING(#{points.first})")
#   else
#     GeoRuby::SimpleFeatures::LinearRing.from_points(points, points.first.srid)
#   end
# end

# def polygon(*points)
#   if points.one? and String === points.first
#     geometry_from_text("POLYGON(#{points})")
#   else
#     GeoRuby::SimpleFeatures::Polygon.from_points([points], points.first.srid)
#   end
# end

# def multi_polygon(polygons)
#   GeoRuby::SimpleFeatures::MultiPolygon.from_polygons(polygons, polygons.first.srid)
# end

