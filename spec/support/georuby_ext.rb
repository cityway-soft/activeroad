def rgeo_factory
  @rgeo_factory ||= ActiveRoad::Base.rgeo_factory
end

def rgeo_point(x = 0, y = 0, srid = 4326)
  rgeo_factory.point(x, y)
end

def rgeo_multi_polygon(polygons, srid = 4326)
  rgeo_factory.multi_polygon(polygons)
end

def rgeo_multi_line_string(multi_line_string, srid = 4326)
  if lines.one? and String === lines.first
    geometry("MULTILINESTRING(#{lines})")
  else
    Rgeo::Geos::MultiLineString.from_line_strings lines, lines.first.srid
  end
end

def rgeometry(text, srid = 4326)
  rgeo_factory.parse_wkt text
end

def rgeo_line_string(text, srid = 4326)
  rgeometry "LINESTRING(#{text})"
end
