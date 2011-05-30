require "#{File.dirname(__FILE__)}/type_converters"

module Mongomatic
  module Attributes

    def self.included(klass) 
      klass.send(:extend, ClassMethods)
    end

    def initialize(doc_hash=Mongomatic::MHash.new, is_new=true)
      super(doc_hash, is_new)
      cast_attributes
    end

    def []=(key, value)
      super(key, cast_attribute(key.to_s, value))
    end

    def set_value_for_key(key, value)
      super(key, cast_attribute(key.to_s, value))
    end

    def attributes
      self.class.attributes
    end

    def attribute_data
      self.class.attribute_data
    end

    def cast_attributes
      self.attribute_data.keys.each do |attr|        
        cast_attribute(attr, self[attr])
      end
    end

    def cast_attribute(attr, val, update=true)
      return val unless self.attribute_data[attr]

      type = self.attribute_data[attr][:typed] 
      converter_klass = TypeConverters.for_type(type)
      return val unless converter_klass
      
      converter = converter_klass.new(val)
      return val if converter.type_match?
      
      cast_val = converter.cast
      self.doc[attr] = cast_val

      cast_val
    end

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
