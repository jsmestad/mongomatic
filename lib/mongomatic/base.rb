module Mongomatic
  class Base
    include Mongomatic
    include Mongomatic::Modifiers
    include Mongomatic::ActiveModelCompliancy
    include Mongomatic::TypedFields

    def transaction(key=nil, duration=5, &block)
      raise Mongomatic::Exceptions::DocumentIsNew if new?
      if key.is_a?(Hash) && key[:scope]
        key = [self.class.name, self["_id"].to_s, key[:scope]].join("-")
      else
        key ||= [self.class.name, self["_id"].to_s].join("-")
      end
      TransactionLock.start(key, duration, &block)
    end
  end
end
