require 'spec_helper'

describe ActiveRoad::LogicalRoad do

  let(:boundary) { create(:boundary)}
  subject { create(:logical_road, :boundary_id => boundary.id) }

  it "should have a name" do
    subject.should respond_to(:name)
  end

  describe "at" do
    
    context "when the given number exists" do

      let(:physical_road) { create :physical_road, :logical_road => subject }
      let(:number) { create :street_number, :physical_road => physical_road }

      it "should return the number geometry" do
        subject.at(number.number).should == number.geometry
        subject.name.should_not be_nil
      end

    end

    context "when the given number is between two existing numbers" do

      let(:physical_road) { create :physical_road, :logical_road => subject }
      let(:number) { 45 }
      let!(:previous_number) do
        physical_road.numbers.create FactoryGirl.attributes_for(:street_number, :location_on_road => 0.5, :number => "30") 
      end
      let!(:next_number) do
        physical_road.numbers.create FactoryGirl.attributes_for(:street_number, :location_on_road => 1, :number => "60")
      end

      let(:estimated_geometry) { subject.geometry.interpolate_point(0.75) }

      it "should return the estimated geometry" do
        subject.at(number).should == estimated_geometry
      end

    end

  end

end
