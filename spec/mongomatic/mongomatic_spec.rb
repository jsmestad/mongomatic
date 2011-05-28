require 'spec_helper'

describe 'Mongomatic Base Module' do
  before(:each) do
    Person.collection.drop
  end
  describe "new instance" do
    subject { Person.new }
    it "is new" do
      subject.should be_new
      subject.is_new?.should be_true
    end
    it "is not removed" do
      subject.should_not be_removed
    end
    it "has no errors" do
      subject.errors.should be_empty
    end
    it "runs after_initialize" do
      subject.called_callbacks.should include :after_initialize
    end
    context "with doc passed in" do
      let(:initial_doc) { {:name => "Jordan"} }
      subject { Person.new(initial_doc) }
      it "is initialized with given doc" do
        subject.doc == initial_doc
      end
    end
  end
  describe "hash methods" do
    let(:name) { "Jordan"}
    let(:city) { "San Francisco" }
    let(:emp_name) { "Making Fun" }
    let(:mm_proj) do 
      {:name => "Mongmatic", 
       :desc => "MongoDB ODM", 
       :contributors => [{:name => "Justin"}, {:name => "Jordan"} ,{:name => "Ben"}]}
    end
    subject do 
        Person.new(:name => name, 
                   :city => city,
                   :employer => { :name => emp_name },
                   :projects => [mm_proj, {:name => "easy_tet", :desc => "Erlang Testing"}])
    end
    specify "equality operator" do
      id = subject.insert
      clone = Person.find_one(id)
      clone.should == subject
    end
    describe "accessors" do
      it "returns value of existing top level key (with string key)" do
        subject['name'].should == name
      end
      it "returns value of existing top level key (with symbol key)" do
        subject[:name].should == name
      end
      it "returns nil for non-existent key" do
        subject['dne'].should be_nil
      end
      it "sets value for top level key" do
        subject[:city] = "Chicago"
        subject['city'].should == "Chicago"
      end   
      it "returns value for nested key" do
        subject['employer.name'].should == emp_name
      end
      it "returns nil for non-existent nested key" do
        subject['employer.income'].should be_nil
      end
      it "sets value for nested key" do
        subject['employer.position'] = "Engineer"
        subject['employer.position'].should == "Engineer"
      end
      it "returns nested hash in array of subdocs" do
        subject['projects.0']['name'].should == mm_proj[:name]
      end
      it "returns nil for non-existent index in array of subdocs that" do
        subject['projects.3'].should be_nil
      end
      it "sets value at index in array of subdocs" do
        subject['projects.3'] = {:name => "ht"}
        subject['projects.3.name'].should == "ht"
      end
      it "returns value for key of doc in array of subdocs" do
        subject['projects.0.name'].should == mm_proj[:name]
      end
      it "returns nil for for non-existent key for doc in array of subdocs" do
        subject['projects.1.contributors'].should be_nil
      end
      it "sets value for key for doc in array of subdocs" do
        subject['projects.1.name'] = "Some New Name"
        subject['projects.1.name'].should == "Some New Name" 
      end
      it "returns subdocument at deeply nested index" do
        subject['projects.0.contributors.1'][:name].should == "Jordan"
      end
      it "returns nil for non-existent index in deeply nested array of subdocs" do
        subject['projects.0.contributors.4'].should be_nil
      end
      it "sets subdocument at index in a deeply nested array of subdocs" do
        subject['projects.0.contributors.3'] = {:name => "Some Dude"}
        subject['projects.0.contributors.3.name'] = "Some Dude"
      end
    end
    describe "#has_key?" do   
      specify "returns true when top-level key exists" do
        subject.should have_key :name
        subject.should have_key 'name'
      end
      specify "returns false when top-level key D.N.E" do
        subject.should_not have_key :age
        subject.should_not have_key 'age'
      end
      specify "returns true when nested key exists" do
        subject.should have_key 'employer.name'      
      end
      specify "returns false when nested key D.N.E" do
        subject.should_not have_key 'employer.income'
      end
      specify "returns true when index in array of subdocs exists" do
        subject.should have_key 'projects.0'
        subject.should have_key 'projects.1'
      end
      specify "returns false when index in array of subdocs D.N.E" do
        subject.should_not have_key 'projects.3'
      end
      specify "returns true if key exists in existing subdoc" do
        subject.should have_key 'projects.1.name'
      end
      specify "returns false if key D.N.E. in existing subdoc" do
        subject.should_not have_key "projects.1.contributors"
      end
      specify "returns false if subdoc does not exist when checking for subdoc key" do
        subject.should_not have_key "projects.3.name"
      end
      specify "returns true for deeply nested index access to array" do
        subject.should have_key "projects.0.contributors.1"
      end
      specify "returns false for non-existent deeply nested index access to array" do
        subject.should_not have_key "projects.0.contributors.3"
      end
      specify "returns true for key in deeply nested subdoc" do
        subject.should have_key "projects.0.contributors.1.name"
      end
      specify "returns false for non-existent key deeply nested in subdoc" do
        subject.should_not have_key "projects.0.contributors.1.age"
      end
    end
    describe "#delete" do
      it "removes existing top-level key (using symbol)" do
        subject.delete(:name)
        subject['name'].should be_nil
      end
      it "removes existing top-level key (using string)" do
        subject.delete('name')
        subject[:name].should be_nil
      end
      it "is silent no-op on non-existent top-level key" do
        subject.delete('age')
        subject.delete(:age)
        subject['age'].should be_nil
      end
    end
    describe "#merge" do
      before(:each) do
        subject.merge(:name => "Jordan", :dog => "Nola")
      end
      it "updates existing keys" do
        subject['name'].should == "Jordan"
      end
      it "creates new keys" do
        subject['dog'].should == "Nola"
      end
    end
  end
  describe "find" do    
    it "returns a cursor" do
      Person.find.should be_kind_of(Mongomatic::Cursor)
    end
    specify "#all is alias for find" do
      Person.all.should be_kind_of(Mongomatic::Cursor)
    end
    context "when no documents exist" do
      it "cursor is empty" do
        Person.find.should be_empty
      end
    end
    context "when documents exist" do
      let(:docs) do
        [{:name => "Jordan"}, {:name => "Ben"}, {:name => "Justin"}]
      end
      before(:each) do
        docs.each do |doc|
          Person.collection.insert(doc)
        end
      end
      it "returns all docs if no query or opts are provided" do
        Person.find.count.should == docs.count
      end
      it "returns only docs matching query" do
        Person.find(:name => /^J/).count.should == 2
      end
    end
  end
  describe "find one" do
    context "when document exists" do
      subject { Person.new(:name => "Jordan", :age => 22) }
      before(:each) do
        @id = subject.insert
      end
      it "returns document when querying by id" do
        Person.find_one(@id).should be_kind_of(Person)
      end
      it "returns document when querying by fields" do
        Person.find_one(:name => "Jordan").should be_kind_of(Person)
      end
      it "returns only one document even with multiple matches" do
        Person.new(:name => "John", :age => 22)
        Person.find_one(:age => 22).should be_kind_of(Person)
      end
    end
    context "when document D.N.E" do
      it "returns nil" do
        Person.find_one(:name => "Jordan").should be_nil
      end
      specify "find_or_intialize returns new document" do
        Person.find_or_initialize(:name => "Jordan").should be_new
      end
    end
  end
  describe "convenience class methods" do
    specify "Class.first when documents exist returns doc instance" do
      Person.new(:name => "Jordan").insert
      Person.first['name'].should == "Jordan"
    end
    specify "Class.first when no documents exists returns nil" do
      Person.first.should be_nil
    end
    specify "Class.empty? returns true when no documents exist" do
      Person.should be_empty
    end
    specify "Class.empty? returns false when docs exist" do
      Person.insert(:name => "Jordan")
      Person.should_not be_empty
    end
    specify "Class.count returns 0 when no docs exist" do
      Person.count.should == 0
    end
    specify "Class.count returns number of existing docs" do
      Person.insert(:name => "Jordan") 
      Person.insert(:name => "Justin")
      Person.count.should == 2      
    end
  end
  describe "enumeration" do
    before(:each) do
      ["Jordan", "Justin", "Ben"].each do |n|
        Person.new(:name => n).insert
      end
    end
    specify "iterating over all documents" do
      i = 0;
      Person.each do |p|
        p.should be_kind_of(Person)
        i += 1
      end
      i.should == Person.collection.count
    end
  end
  describe "unsafe operations" do
    subject { Person.new(:name => "Jordan") }
    describe "insert" do
      context "valid document" do
        before(:each) do
          @id = subject.insert
        end
        it "returns Object Id" do
          @id.should be_kind_of(BSON::ObjectId)
          end
        it "inserts the document" do
          Person.collection.count.should == 1
        end
        it "calls before_insert" do
          subject.called_callbacks.should include :before_insert
        end
        it "calls after_insert" do
          subject.called_callbacks.should include :after_insert
        end
        it "calls before_insert_or_update" do
          subject.called_callbacks.should include :before_insert_or_update
        end
        it "calls after_insert_or_update" do
          subject.called_callbacks.should include :after_insert_or_update
        end
        it "stores the object id in the _id key of the document" do
          subject.doc['_id'].should == @id
        end
        it "marks instance as no longer new" do
          subject.should_not be_new
        end
      end      
      context "invalid document" do
        subject { Person.new(:name => "Jordan") }
        before(:each) do
          subject.stub(:valid?, false)
        end
        it "returns false" do
          subject.insert.should be_false
        end
        it "raises DocumentNotValid when passing :raise => true" do
          expect { subject.insert(:raise => true) }.to raise_exception(Mongomatic::Exceptions::DocumentNotValid)      
        end
      end
    end
    describe "update" do
      before(:each) do
        subject.insert
        subject[:name] = "Justin"
        subject.update
      end
      it "updates document" do
        Person.find_one(subject[:_id])['name'].should == "Justin"
      end
      it "calls before_update" do
        subject.called_callbacks.should include :before_update
      end
      it "calls after_update" do
        subject.called_callbacks.should include :after_update
      end
      it "calls before_insert_or_update" do
        subject.called_callbacks.select { |c| c == :before_insert_or_update }.count.should == 2
      end
      it "calls after_insert_or_update" do
        subject.called_callbacks.select { |c| c == :after_insert_or_update }.count.should == 2
      end
    end
    describe "save" do
      it "inserts document" do
        subject.save
        subject.should_not be_new
      end
      it "updates document" do
        subject.save 
        subject['name'] = "Some New Name"
        subject.save
        Person.find_one(subject['_id'])['name'].should == "Some New Name"
      end
    end
    describe "remove" do
      before(:each) do
        @id = subject.insert
        subject.remove
      end
      it "removes document" do
        Person.find_one(@id).should be_nil
      end
      it "calls before_remove" do
        subject.called_callbacks.should include :before_remove
      end
      it "calls after_remove" do
        subject.called_callbacks.should include :after_remove
      end
    end
  end
  describe "safe operations" do
    subject { Person.new(:name => "Jordan") }
    before(:each) do
      Person.collection.ensure_index([['name', Mongo::ASCENDING]], :unique => true)
        subject.insert!
    end
    after(:each) do
      Person.collection.drop_index('name_1')
    end
    describe "insert!" do
      it "raises Mongo::Operation errors" do
        expect { Person.insert!(:name => "Jordan") }.to raise_exception(Mongo::OperationFailure)
      end
    end
    describe "update!" do
      it "raises Mongo::Operation errors" do
        Person.insert(:name => "John")
        dup = Person.find_one(:name => "John")
        dup['name'] = "Jordan"
        expect { dup.update! }.to raise_exception(Mongo::OperationFailure)
      end
    end
    describe "save!" do
      it "raises Mongo::Operation errors" do
        subject.save!
        expect { Person.new(subject.doc).save! }.to raise_exception(Mongo::OperationFailure)
      end
    end
  end
  it "reloads data" do
    p1 = Person.new(:name => "Jordan")
    p1.insert
    p2 = Person.find_one(:name => "Jordan")
    p2['name'] = "John"
    p2.update
    p1.reload
    p1['name'].should == "John"
  end
end
