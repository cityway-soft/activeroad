require 'spec_helper'

describe ActiveRoad::StreetNumber do

  subject { Factory :street_number }

  it "should have a number" do
    subject.should respond_to(:number)
  end

  describe "#previous" do

    it "should find previous StreetNumber in the same road" do
      other_number = Factory(:street_number, :road => subject.road, :number => subject.number - 50)
      subject.previous.should == other_number
    end
    
  end

  describe "#next" do

    it "should find next StreetNumber in the same road" do
      other_number = Factory(:street_number, :road => subject.road, :number => subject.number + 50)
      subject.next.should == other_number
    end
    
  end

  describe "location_on_road" do
    
    it "should return the stored location_on_road if exists" do
      subject.location_on_road = 0.3
      subject.location_on_road.should == 0.3
    end

    it "should be comptured when not specified at creation" do
      Factory(:street_number, :location_on_road => nil).location_on_road.should_not be_nil
    end

    context "when no location is stored" do

      before(:each) do
        subject.location_on_road = nil
      end

      it "should return 0.5 by default" do
        subject.location_on_road.should == 0.5
      end

      it "should use previous and next numbers to compute location" do
        subject.stub :previous => mock(:number => 50, :location_on_road => 0.5)
        subject.stub :next => mock(:number => 100, :location_on_road => 1)
        subject.number = "75"
        subject.location_on_road.should == 0.75
      end
                                           
    end


  end

end

describe ActiveRoad::StreetNumber::Number do
  
  def number(value)
    ActiveRoad::StreetNumber::Number.new value
  end

  it "should support addition" do
    (number("50bis") + 50).should == number("100bis")
  end

  it "should support subtraction" do
    (number("100bis") - 50).should == number("50bis")
  end

end
