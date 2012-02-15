module ActiveRoad
  class Junction < ActiveRoad::Base
    validates_uniqueness_of :objectid

    has_and_belongs_to_many :physical_roads, :uniq => true
  end
end
