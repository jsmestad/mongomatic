module Mongomatic
  module ClassMethods
    # Returns this models own db attribute if set, otherwise will return Mongomatic.db
    def db
      @db || Mongomatic.db || raise(ArgumentError, "No db supplied")
    end
    
    # Override Mongomatic.db with a Mongo::DB instance for this model specifically
    #  MyModel.db = Mongo::Connection.new().db('mydb_mymodel')
    def db=(obj)
      unless obj.is_a?(Mongo::DB)
        raise(ArgumentError, "Must supply a Mongo::DB object")
      end; @db = obj
    end
    
    # Override this method on your model if you want to use a different collection name
    def collection_name
      self.to_s.tableize
    end
    
    # Return the raw MongoDB collection for this model
    def collection
      @collection ||= self.db.collection(self.collection_name)
    end
        
    # Query MongoDB for documents. Same arguments as 
    # http://api.mongodb.org/ruby/current/Mongo/Collection.html#find-instance_method
    def find(query={}, opts={})
      Mongomatic::Cursor.new(self, collection.find(query, opts))
    end

    # Query MongoDB and return one document only. Same arguments as http://api.mongodb.org/ruby/current/Mongo/Collection.html#find_one-instance_method
    def find_one(query={}, opts={})
      return nil unless doc = self.collection.find_one(query, opts)
      self.new(doc, false)
    end

    # Query MongoDB for existing document. If found, return existing or initialize a new object with the parameters
    def find_or_initialize(query={}, opts={})
      find_one(query, opts) || new(query, true)
    end

    # Same as Class.find
    def all
      find
    end

    # Return the number of documents in the collection
    def count
      collection.count
    end

    # Return the first document in the collection
    def first
      find.limit(1).next_document
    end

    # Is the collection empty? This method is much more efficient than doing Collection.count == 0
    def empty?
      find.limit(1).has_next? == false
    end

    # Iterate over all documents in the collection (uses a Mongomatic::Cursor)
    def each
      find.each { |found| yield(found) }
    end

    # Drop the collection. Calls the class method callbacks before_drop and after_drop
    def drop
      do_callback(:before_drop)
      collection.drop
      do_callback(:after_drop)
    end

    def insert(doc_hash, opts={})
      d = new(doc_hash)
      d.insert(opts)
    end

    def insert!(doc_hash, opts={})
      insert(doc_hash, opts.merge(:safe => true))
    end

    def do_callback(meth)
      return false unless respond_to?(meth, true)
      send(meth)
    end
    private :do_callback
  end
end
