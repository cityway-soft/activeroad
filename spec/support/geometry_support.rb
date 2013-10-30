def geometry_from_text(text, srid = 4326)
  GeoRuby::SimpleFeatures::Geometry.from_ewkt "SRID=#{srid};#{text}"
end

def point(x=0.0, y=0.0, srid = 4326)
  GeoRuby::SimpleFeatures::Point.from_x_y x, y, srid
end

def line_string(*points)
  if points.one? and String === points.first
     geometry_from_text("LINESTRING(#{points.first})")
  else
    GeoRuby::SimpleFeatures::LineString.from_points(points, points.first.srid)
  end
end
