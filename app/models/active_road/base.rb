class ActiveRoad::Base < ActiveRoad::ActiveRecord
  set_table_name "roads"

  validates_uniqueness_of :objectid

  has_many :numbers, :class_name => "ActiveRoad::StreetNumber", :foreign_key => "road_id"

  def at(value)
    if Float === value
      geometry_at_location value
    else
      geometry_at_number value
    end
  end

  def geometry_at_number(number)
    numbers.find_or_initialize_by_number(number.to_s).geometry
  end

  def geometry_at_location(location)
    geometry.interpolate_point(location) if geometry
  end

end
