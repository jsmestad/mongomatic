require 'spec_helper'

describe "Mongomatic Modifiers" do
  subject { Person.new(:name => "Jordan") }
  before(:each) do
    Person.drop
    subject.insert
  end
  describe "push" do
    before(:each) do
      subject.push("interests", "hiking")
    end
    it "upserts key in memory, creating new array with one element" do
      subject['interests'].should == ["hiking"]
    end
    it "upserts key on disk, creating new array with one element" do
      Person.find_one(subject['_id'])['interests'].should == ["hiking"]
    end
    it "appends to array of existing key in memory" do
      subject.push("interests", "coding")
      subject['interests'].last.should == "coding"
    end
    it "appends to array of existing key on disk" do
      subject.push("interests", "coding")
      Person.find_one(subject['_id'])['interests'].last.should == "coding"
    end
    specify "with dotted keys" do
      subject.push("personal.interests", "coding")
      subject['personal']['interests'].should == ["coding"]
    end
  end
  describe "push_all" do
    let(:initial_coworkers) { ["Lee", "Sky"] }
    let(:later_coworkers) { ["Mike", "Paul"] }
    before(:each) do
      subject.push_all("coworkers", initial_coworkers)     
    end
    it "upserts key in memory, creating given array" do
      subject['coworkers'].should == initial_coworkers
    end
    it "upserts key on disk, creating given array" do
      Person.find_one(subject['_id'])['coworkers'].should == initial_coworkers
    end
    it "appends given array to end of array at key in-memory" do
      subject.push_all("coworkers", later_coworkers)
      subject['coworkers'].should == (initial_coworkers + later_coworkers)
    end
    it "appends given array to end of array at key on-disk" do
      subject.push_all("coworkers", later_coworkers)
      Person.find_one(subject['_id'])['coworkers'].should == (initial_coworkers + later_coworkers)
    end
    specify "using dotted keys" do
      subject.push_all("contacts.coworkers", initial_coworkers)
      subject['contacts.coworkers'].should == initial_coworkers
    end
  end
  describe "pull" do
    before(:each) do
      subject.push_all("coworkers", ["Lee", "Mike", "Paul", "Sky"])
      subject.pull("coworkers", "Sky")
    end
    it "is silent on non-existent key" do
      expect { subject.pull("family", "some one") }.to_not raise_exception
    end
    it "removes item from array in-memory" do
      subject['coworkers'].should_not include "Sky"
    end
    it "removes item from array on-disk" do
      Person.find_one(subject['_id'])['coworkers'].should_not include "Sky"
    end
  end
  describe "pull_all" do
    before(:each) do
      subject.push_all("coworkers", ["Lee", "Mike", "Paul", "Sky"])
      subject.pull_all("coworkers", ["Sky", "Paul"])
    end
    it "is silent on non-existent key" do
      expect { subject.pull_all("family", ["a", "b"]) }.to_not raise_exception
    end
    it "removes items from array in-memory" do
      subject['coworkers'].should == ["Lee", "Mike"]
    end
    it "removes items from array on-disk" do
      Person.find_one(subject['_id'])['coworkers'].should == ["Lee", "Mike"]
    end
  end
  describe "inc" do
    let(:init_val) { 2 }
    let(:n) { 3 }
    before(:each) do
      subject.inc("num_gold", init_val)
    end
    it "upserts value when key does not exist (in-memory)" do
      subject['num_gold'].should == init_val
    end
    it "upserts value whne key does not exist (on-disk)" do
      Person.find_one(subject['_id'])['num_gold'].should == init_val
    end
    it "increments existing value when number is positive (in-memory)" do
      subject.inc("num_gold", n)
      subject['num_gold'].should == init_val + n
    end
    it "increments existing value when number is positive (on-disk)" do
      subject.inc("num_gold", n)
      Person.find_one(subject['_id'])['num_gold'].should == init_val + n
    end
    it "decrements existing value when number is negative" do
      subject.inc("num_gold", 0 - n)
      Person.find_one(subject['_id'])['num_gold'].should == init_val - n
    end
    it "defaults n to one" do
      subject.inc("num_gold")
      subject['num_gold'].should == init_val + 1
    end
    specify "using dotted keys" do
      subject['projects'] = [{:name => "Mongomatic"}, {:name => "easy_test"}]
      subject.inc('projects.0.contributor_count', n)
      subject['projects.0.contributor_count'].should == n
    end
  end
  describe "set" do
    before(:each) do
      subject['projects'] = [{:name => "Mongomatic"}, {:name => "easy_test"}]
      subject.update
      subject.set('age', 22)
      subject.set('name', "John")
    end
    it "upserts key in-memory" do
      subject['age'].should == 22
    end
    it "upserts key on disk" do
      Person.find_one(subject['_id'])['age'].should == 22
    end
    it "updates existing value for key in-memory" do
      subject['name'].should == "John"
    end
    it "updates existing value for key on disk" do
      Person.find_one(subject['_id'])['name'].should == "John"
    end
    specify "with dotted keys" do
      # set on existing
      subject.set('projects.0.name', "Some New Name")
      Person.find_one(subject['_id'])['projects.0.name'].should == "Some New Name"

      # set on new
      subject.set('projects.3.name', "Abc")
      Person.find_one(subject['_id'])['projects.3']['name'].should == "Abc"
    end
  end
  describe "unset" do
    before(:each) do
      subject['projects'] = [{:name => "Mongomatic"}, {:name => "easy_test"}]
      subject.update
      subject.unset('name')
    end
    it "is silent on non-existent key" do
      expect { subject.unset('last_name') }.to_not raise_exception
    end
    it "sets existing key to nil in-memory" do
      subject['name'].should be_nil
    end
    it "sets existing key to nil on disk" do
      Person.find_one(subject['_id'])['name'].should be_nil
    end
    specify "with dotted keys" do
      subject.unset('projects.0.name')
      subject['projects.0.name'].should be_nil
      subject['projects.0'].should_not be_nil
    end
  end
  describe "add_to_set" do
    before(:each) do
      subject.add_to_set('coworkers', ["Lee", "Mike"])
      subject.add_to_set('interests', "coding")
    end
    it "upserts non-existent keys in-memory" do
      subject['coworkers'].should == ["Lee", "Mike"]
      subject['interests'].should == ["coding"]
    end
    it "upserts non-existent keys on-disk" do
      p = Person.find_one(subject['_id']) 
      p['coworkers'].should == ["Lee", "Mike"]
      p['interests'].should == ["coding"]
    end
    it "adds new element to exisiting value in-memory" do
      subject.add_to_set('interests', "hiking")
      subject['interests'].should include "hiking"
    end
    it "adds new element to existing value on disk" do
      subject.add_to_set('interests', "hiking")
      Person.find_one(subject['_id'])['interests'].should include "hiking"
    end
    it "does not add existing element" do
      subject.add_to_set('interests', "coding")
      subject['interests'].select { |i| i == "coding" }.count.should == 1
    end
  end
  describe "pop_first" do
    before(:each) do
      subject.push_all('coworkers', ["Lee", "Mike"])
      subject.pop_first('coworkers')
    end
    it "is silent on non-existent key" do
      expect { subject.pop_first("projects") }.to_not raise_exception
    end
    it "is silent on empty array" do
      subject['interests'] = []
      subject.update
      expect { subject.pop_first('interests') }.to_not raise_exception
    end
    it "removes first element of array in-memory" do
      subject['coworkers'].should == ["Mike"]
    end
    it "removes first element of array on-disk" do
      Person.find_one(subject['_id'])['coworkers'].should == ["Mike"]
    end
  end
  describe "pop_last" do
    before(:each) do
      subject.push_all('coworkers', ["Lee", "Mike"])
      subject.pop_last('coworkers')
    end    
    it "is silent on non-existent key" do
      expect { subject.pop_last("projects") }.to_not raise_exception
    end
    it "is silent on empty array" do
      subject['interests'] = []
      subject.update
      expect { subject.pop_last('interests') }.to_not raise_exception
    end
    it "removes last element of array in-memory" do
      subject['coworkers'].should == ["Lee"]
    end
    it "removes last element of array on-disk" do
      Person.find_one(subject['_id'])['coworkers'].should == ["Lee"]
    end
  end
end
