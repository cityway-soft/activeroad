require 'spec_helper'

describe ActiveRoad::Base do

  subject { Factory(:road) }

  it "should have a name" do
    subject.should respond_to(:name)
  end

  describe "at" do
    
    context "when the given number exists" do

      let(:number) { Factory :street_number, :road => subject }

      it "should return the number geometry" do
        subject.at(number.number).should == number.geometry
      end

    end

    context "when the given number is between two existing numbers" do

      let(:number) { 45 }
      let!(:previous_number) do
        subject.numbers.create Factory.attributes_for(:street_number, :location_on_road => 0.5, :number => "30") 
      end
      let!(:next_number) do
        subject.numbers.create Factory.attributes_for(:street_number, :location_on_road => 1, :number => "60")
      end

      let(:estimated_geometry) { subject.geometry.interpolate_point(0.75) }

      it "should return the estimated geometry" do
        subject.at(number).should == estimated_geometry
      end

    end

  end

end
