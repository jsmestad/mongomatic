require 'bundler/setup'
require 'rspec'
require 'mongomatic'

Mongomatic.db = Mongo::Connection.new.db("mongomatic_test")

class Person
  include Mongomatic

  def called_callbacks
    @called_callbacks ||= []
  end

  def after_initialize
    @called_callbacks ||= []
    @called_callbacks << :after_initialize
  end

  def before_insert
    @called_callbacks ||= []
    @called_callbacks << :before_insert
  end

  def after_insert
    @called_callbacks ||= []
    @called_callbacks << :after_insert
  end

  def before_insert_or_update
    @called_callbacks ||= []
    @called_callbacks << :before_insert_or_update
  end

  def after_insert_or_update
    @called_callbacks ||= []
    @called_callbacks << :after_insert_or_update
  end

  def before_update
    @called_callbacks ||= []
    @called_callbacks << :before_update
  end
  
  def after_update
    @called_callbacks ||= []
    @called_callbacks << :after_update
  end

  def before_remove
    @called_callbacks ||= []
    @called_callbacks << :before_remove
  end

  def after_remove
    @called_callbacks ||= []
    @called_callbacks << :after_remove
  end
end

class GameObject
  include Mongomatic

  attribute :silver_count
  attribute :gold_count, :typed => Fixnum
  attribute :name, :typed => String
  attribute :x_pos, :typed => Float
  attribute :item, :typed => BSON::ObjectId

end

