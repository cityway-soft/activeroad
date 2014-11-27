# -*- coding: utf-8 -*-
require 'spec_helper'

describe ActiveRoad::StreetNumber do

  subject { create :street_number }

  it "should have a number" do
    expect(subject).to respond_to(:number)
  end

  describe ".computed_linked_road" do
    let(:pr) { create(:physical_road, :geometry => "LINESTRING(0 0,1 0)", :name => "Rue de l'Armée") }
    let(:street_number_closed) { create(:street_number, :geometry => "POINT(0.1 0.001)", :physical_road => pr) }
    let(:street_number_same_name) { create(:street_number, :geometry => "POINT(0.1 0.001)", :physical_road => pr, :street => "Rue de l'Armée" ) }    
    let(:street_number_nok) { create(:street_number, :geometry => "POINT(0.1 1)", :physical_road => pr) }    
    
    it "should find physical_road if street number has same name and closed to it" do
      expect(ActiveRoad::StreetNumber.computed_linked_road(street_number_same_name.geometry, street_number_same_name.street)).to eq(pr)
    end

    it "should find physical_road if street number hasn't the same name but closed to it" do
      expect(ActiveRoad::StreetNumber.computed_linked_road(street_number_closed.geometry, street_number_closed.street)).to eq(pr)
    end

    it "should not find physical_road if street number hasn't the same name and far from it" do
      expect(ActiveRoad::StreetNumber.computed_linked_road(street_number_nok.geometry, street_number_nok.street)).to eq(nil)
    end
    
  end
  
  describe "#computed_linked_road" do
    let(:pr) { create(:physical_road, :geometry => "LINESTRING(0 0,1 0)", :name => "Rue Vaugirard") }
    let(:street_number_closed) { create(:street_number, :geometry => "POINT(0.1 0.001)", :physical_road => pr) }
    let(:street_number_same_name) { create(:street_number, :geometry => "POINT(0.1 0.001)", :physical_road => pr, :street => "Rue Vaugirard" ) }    
    let(:street_number_nok) { create(:street_number, :geometry => "POINT(0.1 1)", :physical_road => pr) }    
    
    it "should find physical_road if street number has same name and closed to it" do
      street_number_same_name.computed_linked_road
      expect(street_number_same_name.road).to eq(pr)
    end

    it "should find physical_road if street number hasn't the same name but closed to it" do
      street_number_closed.computed_linked_road
      expect(street_number_closed.road).to eq(pr)
    end

    it "should not find physical_road if street number hasn't the same name and far from it" do
      street_number_nok.computed_linked_road
      expect(street_number_nok.road).to eq(nil)
    end
    
  end
  
  describe "#computed_geometry" do
    let(:pr) { create(:physical_road, :geometry => "LINESTRING(0 0,1 0)") }
    let(:street_number_middle) { create(:street_number, :geometry => nil, :physical_road => pr, :location_on_road => nil) }    
    
    it "should find computed geometry" # do
    #   expect(subject.computed_geometry).to eq(nil)
    # end
    
  end  

  describe "#compute_locate_on_road" do
    let(:pr) { create(:physical_road, :geometry => "LINESTRING(0 0,1 0)") }
    let(:street_number_left) { create(:street_number, :geometry => "POINT(-1 1)", :physical_road => pr, :location_on_road => nil) }
    let(:street_number_right) { create(:street_number, :geometry => "POINT(2 1)", :physical_road => pr, :location_on_road => nil) }
    let(:street_number_middle) { create(:street_number, :geometry => "POINT(0.5 0.5)", :physical_road => pr, :location_on_road => nil) }

    it "should return 0 if street number is on the left side for physical road" do
      street_number_left.computed_location_on_road
      expect( street_number_left.location_on_road ).to eq(0)
    end

    it "should return 1 if street number is on the right side for physical road" do
      street_number_right.computed_location_on_road
      expect( street_number_right.location_on_road ).to eq(1)
    end

    it "should return 0.5 if street number is on the middle side for physical road" do
      street_number_middle.computed_location_on_road
      expect( street_number_middle.location_on_road ).to eq(0.5)
    end
    
  end
  
  describe "#location_on_road" do
    
    it "should return the stored location_on_road if exists" do
      subject.location_on_road = 0.3
      expect(subject.location_on_road).to eq(0.3)
    end

    context "when no location is stored" do

      before(:each) do
        subject.location_on_road = nil
      end

      it "should return nil" do
        expect(subject.location_on_road).to be_nil
      end

      it "should use previous and next numbers to compute location" do
        allow(subject).to receive_messages :previous => double(:number => 50, :location_on_road => 0.5)
        allow(subject).to receive_messages :next => double(:number => 100, :location_on_road => 1)
        subject.number = "75"
        expect(subject.location_on_road).to eq(0.75)
      end
                                           
    end

  end

  describe "#previous" do

    it "should find previous StreetNumber in the same road" do
      other_number = create(:street_number, :physical_road => subject.road, :number => subject.number - 50)
      expect(subject.previous).to eq(other_number)
    end
    
  end

  describe "#next" do

    it "should find next StreetNumber in the same road" do
      other_number = create(:street_number, :physical_road => subject.road, :number => subject.number + 50)
      expect(subject.next).to eq(other_number)
    end
    
  end
  
  describe "#even?" do
    let(:street_number_even) { create(:street_number, :number => "4")}
    
    it "should return true if street number is even" do
      expect(street_number_even.even?).to be_truthy
    end
    
  end

  describe "#odd?" do
    let(:street_number_odd) { create(:street_number, :number => "5")}
    
    it "should return true if street number is odd" do
      expect(street_number_odd.odd?).to be_truthy
    end

  end

end

describe ActiveRoad::StreetNumber::Number do
  
  def number(value)
    ActiveRoad::StreetNumber::Number.new value
  end

  it "should support addition" do
    expect(number("50bis") + 50).to eq( number("100bis") )
  end

  it "should support subtraction" do
    expect(number("100bis") - 50).to eq( number("50bis") )
  end

end
