FactoryGirl.define do

  factory :boundary, :class => ActiveRoad::Boundary do
    sequence(:objectid) { |n|  "boundary::#{n}" }
    sequence(:name) { |n|  "Boundary #{n}" }
  end

end
