module Mongomatic

  class Boolean; end # used to allow type conversions to a "Boolean" type

  module TypeConverters
    class CannotCastValue < RuntimeError; end
    
    def self.for_type(type)
      return nil unless type
      type_s = type.to_s
      type_val = type_s =~ /::/ ? type_s.split(/::/).last.to_sym : type_s.to_sym
      if check_const(type_val)
        self.get_const(type_val)
      end
    end
    
    def self.check_const(type)
      if RUBY_VERSION =~ /^1\.8/
        self.const_defined?(type)
      else
        self.const_defined?(type, false)
      end
    end

    def self.get_const(type)
      if RUBY_VERSION =~ /^1\.8/
        self.const_get(type)
      else
        self.const_get(type, false)
      end

    end
    
    class Base
      def initialize(orig_val)
        @orig_val = orig_val
      end
      
      def type_match?
        raise "abstract"
      end
      
      def cast
        return nil unless @orig_val
        if type_match?
          @orig_val
        else
          converted = convert_orig_val
          converted.nil? ? raise(CannotCastValue) : converted
        end
      end
      
      def convert_orig_val
        raise "abstract"
      end
    end
    
    class String < Base
      def type_match?
        @orig_val.kind_of? ::String
      end
      
      def convert_orig_val
        @orig_val.respond_to?(:to_s) ? @orig_val.to_s : nil
      end
    end
    
    class Float < Base
      def type_match?
        @orig_val.kind_of? ::Float
      end
      
      def convert_orig_val
        @orig_val.respond_to?(:to_f) ? @orig_val.to_f : nil
      end
    end
    
    class Fixnum < Base
      def type_match?
        @orig_val.kind_of? ::Fixnum
      end
      
      def convert_orig_val
        @orig_val.respond_to?(:to_i) ? @orig_val.to_i : nil
      end
    end
    
    class Array < Base
      def type_match?
        @orig_val.kind_of? ::Array
      end
      
      def convert_orig_val
        @orig_val.respond_to?(:to_a) ? @orig_val.to_a : nil
      end
    end

    class Hash < Base
      def type_match?
        @orig_val.kind_of? ::Hash
      end
      
      def convert_orig_val
        [:to_h, :to_hash].each do |meth|
          res = (@orig_val.respond_to?(meth) ? @orig_val.send(meth) : nil)
          return res if !res.nil?
        end; nil
      end
    end

    class Boolean < Base
      def type_match?
        @orig_val == true || @orig_val == false
      end
      
      def convert_orig_val
        s_val = @orig_val.to_s.downcase
        if %w(1 t true y yes).include?(s_val)
          true
        elsif %w(0 f false n no).include?(s_val)
          false
        else
          nil
        end
      end
    end
        
    class Time < Base
      def type_match?
        @orig_val.kind_of? ::Time
      end

      def convert_orig_val
        ::Time.parse(@orig_val.to_s)
      rescue ArgumentError => e
        nil
      end
    end
    
    class Regex < Base
      def type_match?
        @orig_val.kind_of? ::Regexp
      end
      
      def convert_orig_val
        ::Regexp.new(@orig_val.to_s)
      end
    end
    
    class Symbol < Base
      def type_match?
        @orig_val.kind_of? ::Symbol
      end
      
      def convert_orig_val
        @orig_val.respond_to?(:to_sym) ? @orig_val.to_sym : nil
      end
    end
    
    class ObjectId < Base
      def type_match?
        @orig_val.kind_of? ::BSON::ObjectId
      end
      
      def convert_orig_val
        ::BSON::ObjectId(@orig_val.to_s)
      rescue ::BSON::InvalidObjectId => e
        nil
      end
    end
    
  end
end
