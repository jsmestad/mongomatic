require "#{File.dirname(__FILE__)}/type_converters"

module Mongomatic
  class InvalidType < RuntimeError; end

  module Attributes

    def self.included(klass) 
      klass.send(:extend, ClassMethods)
    end

    def initialize(doc_hash=Mongomatic::MHash.new, is_new=true)
      super(doc_hash, is_new)
      check_or_cast_attributes
    end

    def []=(key, value)
      super(key, check_or_cast_attribute(key.to_s, value, self.attribute_data[key.to_s]))
    end

    def set_value_for_key(key, value)
      super(key, check_or_cast_attribute(key.to_s, value, self.attribute_data[key.to_s]))
    end

    def attributes
      self.class.attributes
    end

    def attribute_data
      self.class.attribute_data
    end

    def check_or_cast_attributes
      self.attribute_data.keys.each do |attr|        
        check_or_cast_attribute(attr, self[attr], self.attribute_data[attr])
      end
    end

    def check_or_cast_attribute(attr, val, opts = {})
      return val unless self.attribute_data[attr]

      type = opts[:typed] 
      check_only = (opts.has_key?(:cast) && !opts[:cast])
      converter_klass = TypeConverters.for_type(type)
      return val unless converter_klass
      
      converter = converter_klass.new(val)
      return val if converter.type_match?      

      raise InvalidType.new("#{attr} should be type: #{type}. Given: #{val}") if val && check_only # let nil values pass type checks
      cast_val = converter.cast
      self.doc[attr] = cast_val

      cast_val
    end

    # overrides default #valid? method
    # really this makes the original #valid? method
    # useless, but if Mongomatic::Attributes
    # becomes optional module then it will be needed
    # also, its more explicit to leave the original for now
    # even if it is a bit ugly
    def valid?
      self.errors = Mongomatic::Errors.new
      do_callback(:before_validate)
      check_required_fields
      validate
      do_callback(:after_validate)
      self.errors.empty?
    end

    def check_required_fields
      self.attribute_data.each do |attr, opts|
        next unless opts[:required]
        self.errors.add attr, "#{attr} is required but is nil" unless self[attr]
      end
    end
    private :check_required_fields

    module ClassMethods

      def attribute(name, opts = {})
        init_attributes
        define_attribute_methods(name) unless @attributes[name]
        @attributes[name.to_s] = opts
      end

      def attributes
        init_attributes
        @attributes.keys.map(&:to_sym)
      end

      def attribute_data
        init_attributes
        @attributes 
      end

      def init_attributes
        @attributes ||= {}
      end
      private :init_attributes

      def define_attribute_methods(name)
        self.instance_eval do

          # define reader for attribute
          define_method(name) do
            self[name]
          end

          # define writer for attribute
          define_method("#{name}=") do |val|
            self[name] = val
          end

        end
      end
      private :define_attribute_methods

    end
  end
end
