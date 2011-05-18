module Mongomatic
  class Errors
    def initialize
      @errors = HashWithIndifferentAccess.new
    end

    def add(field, message)
      @errors[field] ||= []
      @errors[field] << message
    end

    def <<(error_array)
      error_array = Array(error_array)
      if error_array.size == 2
        add error_array[0], error_array[1]
      else
        add_to_base error_array[0]
      end
    end

    def add_to_base(message)
      @errors["base"] ||= []
      @errors["base"] << message
    end

    def remove(field, message)
      @errors[field] ||= []
      @errors[field].delete message
    end

    def empty?
      !(@errors.any? { |k,v| v && !v.empty? })
    end

    def any?
      !empty?
    end

    def count
      @errors.values.inject(0) { |sum, errors| sum += errors.size }
    end

    def full_messages
      full_messages = []
      @errors.each do |field, messages|
        messages.each do |message|
          msg = []
          msg << field unless field == "base"
          msg << message
          full_messages << msg.join(" ")
        end
      end
      full_messages
    end

    def [](field)
      @errors[field] || []
    end

    def to_hash
      @errors
    end

    def on(field)
      self[field]
    end
  end
end

# module Mongomatic
#   class Errors < Array
#     def full_messages(sep=" ")
#       collect { |e| e.join(sep) }
#     end
#
#     def on(field, sep=" ")
#       ret = []
#       self.each do |err|
#         ret << err.join(sep) if err.first =~ /^#{field.to_s.split('_').join(' ')}/i
#       end
#       case ret.size
#       when 0
#         nil
#       when 1
#         ret.first
#       else
#         ret
#       end
#     end
#   end
# end