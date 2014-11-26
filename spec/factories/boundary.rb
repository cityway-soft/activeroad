FactoryGirl.define do

  factory :boundary, :class => ActiveRoad::Boundary do
    sequence(:objectid) { |n|  "boundary::#{n}" }
    sequence(:name) { |n|  "Boundary #{n}" }
    geometry "MULTIPOLYGON( ((1 1,5 1,5 5,1 5,1 1),(2 2,2 3,3 3,3 2,2 2)),((6 3,9 2,9 4,6 3)) )"
  end

end
