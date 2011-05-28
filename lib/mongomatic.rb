require 'bson'
require 'mongo'

require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash'

require "#{File.dirname(__FILE__)}/mongomatic/m_hash"
require "#{File.dirname(__FILE__)}/mongomatic/errors"
require "#{File.dirname(__FILE__)}/mongomatic/cursor"

module Mongomatic

  # Mongomatic Module Functions
  class << self
    # Returns an instance of Mongo::DB
    def db
      @db
    end
    
    # Set to an instance of Mongo::DB to be used for all models:
    #  Mongomatic.db = Mongo::Connection.new().db('mydb')
    def db=(obj)
      unless obj.is_a?(Mongo::DB)
        raise(ArgumentError, "Must supply a Mongo::DB object")
      end; @db = obj
    end
  end

  def self.included(klass)
    klass.send(:attr_accessor, :removed, :is_new, :errors)
    klass.send(:attr_reader, :doc)
    klass.send(:extend, ClassMethods)
  end

  # Public Instance Methods
  def initialize(doc_hash=Mongomatic::MHash.new, is_new=true)
    self.doc = doc_hash
    self.removed = false
    self.is_new  = is_new
    self.errors  = Mongomatic::Errors.new
    do_callback(:after_initialize)
  end

  # Insert the document into the database. Will return false if the document has
  # already been inserted or is invalid. Returns the generated BSON::ObjectId
  # for the new document. Will silently fail if MongoDB is unable to insert the
  # document, use insert! or send in {:safe => true} if you want a Mongo::OperationError.
  # If you want to raise the following errors also, pass in {:raise => true}
  #   * Raises Mongomatic::Exceptions::DocumentNotNew if document is not new
  #   * Raises Mongomatic::Exceptions::DocumentNotValid if there are validation errors
  def insert(opts={})
    if opts[:raise] == true
      raise Mongomatic::Exceptions::DocumentWasRemoved if removed?
      raise Mongomatic::Exceptions::DocumentNotNew unless new?
      raise Mongomatic::Exceptions::DocumentNotValid unless valid?
    else
      return false unless new? && valid?
    end

    do_callback(:before_insert)
    do_callback(:before_insert_or_update)
    if ret = self.class.collection.insert(@doc,opts)
      @doc["_id"] = @doc.delete(:_id) if @doc[:_id]
      self.is_new = false
    end
    do_callback(:after_insert)
    do_callback(:after_insert_or_update)
    ret
  end

  # Calls insert(...) with {:safe => true} passed in as an option.
  #   * Raises Mongo::OperationFailure if there was a DB error on inserting
  # If you want to raise the following errors also, pass in {:raise => true}
  #   * Raises Mongomatic::Exceptions::DocumentNotNew if document is not new
  #   * Raises Mongomatic::Exceptions::DocumentNotValid if there are validation errors
  def insert!(opts={})
    insert(opts.merge(:safe => true))
  end

  # Will persist any changes you have made to the document. Silently fails on
  # db update error. Use update! or pass in {:safe => true} to raise a
  # Mongo::OperationError if that's what you want.
  # If you want to raise the following errors also, pass in {:raise => true}
  #   * Raises Mongomatic::Exceptions::DocumentIsNew if document is new
  #   * Raises Mongomatic::Exceptions::DocumentNotValid if there are validation errors
  #   * Raises Mongomatic::Exceptions::DocumentWasRemoved if document has been removed
  def update(opts={},update_doc=@doc)
    if opts[:raise] == true
      raise Mongomatic::Exceptions::DocumentWasRemoved if removed?
      raise Mongomatic::Exceptions::DocumentIsNew      if new?
      raise Mongomatic::Exceptions::DocumentNotValid   unless valid?
    else
      return false if new? || removed? || !valid?
    end
    do_callback(:before_update)
    do_callback(:before_insert_or_update)
    ret = self.class.collection.update({"_id" => @doc["_id"]}, update_doc, opts)
    do_callback(:after_update)
    do_callback(:after_insert_or_update)
    ret
  end

  # Calls update(...) with {:safe => true} passed in as an option.
  #   * Raises Mongo::OperationError if there was a DB error on updating
  # If you want to raise the following errors also, pass in {:raise => true}
  #   * Raises Mongomatic::Exceptions::DocumentIsNew if document is new
  #   * Raises Mongomatic::Exceptions::DocumentNotValid if there are validation errors
  #   * Raises Mongomatic::Exceptions::DocumentWasRemoved if document has been removed
  def update!(opts={},update_doc=@doc)
    update(opts.merge(:safe => true),update_doc)
  end

  # If the document is new then an insert is performed, otherwise, an update is peformed.
  def save(opts={})
    (new?) ? insert(opts) : update(opts)
  end

  # Calls save(...) with {:safe => true} passed in as an option.
  def save!(opts={})
    save(opts.merge(:safe => true))
  end

  # Remove this document from the collection. Silently fails on db error,
  # use remove! or pass in {:safe => true} if you want an exception raised.
  # If you want to raise the following errors also, pass in {:raise => true}
  #   * Raises Mongomatic::Exceptions::DocumentIsNew if document is new
  #   * Raises Mongomatic::Exceptions::DocumentWasRemoved if document has been already removed
  def remove(opts={})
    if opts[:raise] == true
      raise Mongomatic::Exceptions::DocumentWasRemoved if removed?
      raise Mongomatic::Exceptions::DocumentIsNew      if new?
    else
      return false if new? || removed?
    end
    do_callback(:before_remove)
    if ret = self.class.collection.remove({"_id" => @doc["_id"]})
      self.removed = true; freeze; ret
    end
    do_callback(:after_remove)
    ret
  end

  # Calls remove(...) with {:safe => true} passed in as an option.
  #   * Raises Mongo::OperationError if there was a DB error on removing
  # If you want to raise the following errors also, pass in {:raise => true}
  #   * Raises Mongomatic::Exceptions::DocumentIsNew if document is new
  #   * Raises Mongomatic::Exceptions::DocumentWasRemoved if document has been already removed
  def remove!(opts={})
    remove(opts.merge(:safe => true))
  end

  # Reload the document from the database
  def reload
    if obj = self.class.find_one(@doc["_id"])
      self.doc = obj.doc; true
    end
  end

  # Check equality with another Mongomatic document
  def ==(obj)
    obj.is_a?(self.class) && obj.doc["_id"] == @doc["_id"]
  end

  # Returns true if document contains key
  def has_key?(key)
    field, res, depth = hash_for_field(key.to_s, true)
    case res
    when Hash      
      res.has_key?(field)
    when Array
      !res[key.split('.')[depth].to_i].nil?
    end
  end

  def value_for_key(key)
    field, res, depth = hash_for_field(key.to_s, true)
    field_accessor = res.kind_of?(Hash) ? field : field.to_i
    res[field_accessor]
  end
  alias :[] :value_for_key

  def set_value_for_key(key, value)
    field, res, depth = hash_for_field(key.to_s)
    field_accessor = res.kind_of?(Hash) ? field : field.to_i
    val = value.kind_of?(Hash) ? Mongomatic::MHash.new(value) : value
    res[field_accessor] = val
  end
  alias :[]= :set_value_for_key

  # Merge this document with the supplied hash. Useful for updates:
  #  mydoc.merge(params[:user])
  def merge(hash)
    hash.each { |k,v| self[k] = v }; @doc
  end

  ##
  # Same as Hash#delete
  #
  # mydoc.delete("name")
  #  => "Ben"
  # mydoc.has_hey?("name")
  #  => false
  def delete(key)
    @doc.delete(key)
  end


  # Return this document as a hash.
  def to_hash
    @doc || {}
  end

  def valid?
#    check_typed_fields! REMOVING TYPE FIELDS CHECK FOR NOW
    self.errors = Mongomatic::Errors.new
    do_callback(:before_validate)
    validate
    do_callback(:after_validate)
    self.errors.empty?
  end

  def doc=(hash)
    hash = Mongomatic::MHash.new(hash) unless hash.is_a?(Mongomatic::MHash)
    @doc = hash
  end
  
  def new?
    self.is_new == true
  end

  def is_new?
    !!new?
  end

  # Will return true if the document has been removed.
  def removed?
    self.removed == true
  end

  # Private Instance Methods
  def do_callback(meth)
    notify(meth) if self.class.included_modules.include?(Mongomatic::Observable) # TODO entire block is smelly, doesnt belong here
    return false unless respond_to?(meth, true)
    send(meth)
  end
  private :do_callback

  def hash_for_field(field, break_if_dne=false)
    parts = field.split(".")
    curr_hash = self.doc
    return [parts[0], curr_hash] if parts.size == 1
    field = parts.pop # last one is the field
    parts.each_with_index do |part, i|
      part_accessor = curr_hash.kind_of?(Array) ? part.to_i : part
      part_exists = curr_hash.kind_of?(Array) ? !curr_hash[part_accessor].nil? : curr_hash.has_key?(part_accessor)
      return [part, curr_hash, i] if break_if_dne && !part_exists  # !curr_hash.has_key?(part_accessor)
      curr_hash[part_accessor] ||= {}
      return [field, curr_hash[part_accessor], i+1] if parts.size == i+1
      curr_hash = curr_hash[part_accessor]
    end
  end
  private :hash_for_field


  # Override this with your own validate() method for validations.
  # Simply push your errors into the self.errors property and
  # if self.errors remains empty your document will be valid.
  #  def validate
  #    self.errors.add "name", "cannot be blank"
  #  end
  def validate
    true
  end
  private :validate

  # Class Methods
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

require "#{File.dirname(__FILE__)}/mongomatic/observer"
require "#{File.dirname(__FILE__)}/mongomatic/observable"
require "#{File.dirname(__FILE__)}/mongomatic/exceptions"
require "#{File.dirname(__FILE__)}/mongomatic/util"
require "#{File.dirname(__FILE__)}/mongomatic/modifiers"
require "#{File.dirname(__FILE__)}/mongomatic/expectations"
require "#{File.dirname(__FILE__)}/mongomatic/active_model_compliancy"
require "#{File.dirname(__FILE__)}/mongomatic/type_converters"
require "#{File.dirname(__FILE__)}/mongomatic/typed_fields"
require "#{File.dirname(__FILE__)}/mongomatic/base"
require "#{File.dirname(__FILE__)}/mongomatic/transaction_lock"
