require 'spec_helper'

describe "Mongomatic Attributes" do
  subject { GameObject.new(:silver_count => 2, :gold_count => "2", :friends => ["Tariq", "Cosmin"]) }
  describe "fetching list of attributes" do
    it "returns empty list when no attributes are defined" do
      Person.attributes.should == []
    end
    it "returns list of attributes as symbols when they are defined" do
      GameObject.attributes.count.should == 5
      GameObject.attributes.each { |a| a.should be_kind_of Symbol }
    end
  end
  describe "attribute methods" do
    it "defines a reader instance method for each attribute" do
      GameObject.attributes.each do |a|
        subject.should respond_to a
      end
    end
    it "defines a writer instance method for each attribute" do
      GameObject.attributes.each do |a|
        subject.should respond_to "#{a}=".to_sym
      end
    end
    specify "reader returns value for attribute" do
      subject.silver_count.should == subject['silver_count']
    end
    specify "writer updates value for attribute" do
      subject.silver_count = 0
      subject.silver_count.should == 0
    end
  end
  describe "type casting" do
    it "casts type on creation" do
      subject['gold_count'].should == 2
      subject.gold_count.should == 2
    end
    it "casts on update" do
      subject['gold_count'] = "3"
      subject.gold_count.should == 3
      subject.gold_count = 4.12
      subject['gold_count'].should == 4
    end
    specify "casting to String" do
      subject.name = 1
      subject.name.should == "1"
    end
    specify "casting to Float" do
      subject.x_pos = "1.23"
      subject['x_pos'].should == 1.23
    end
    specify "casting to ObjectId" do
      id = subject.insert!
      subject.item = id.to_s
      subject.item.should be_kind_of BSON::ObjectId
    end
  end
end
