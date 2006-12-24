# A way to override modules' methods.
#
# To make Kernel#system always return true, execute:
#   Kernel.override!(:system).and_return true
#
# To restore the original Kernel#system, do:
#   Kernel.restore! :system
#

class Module
  class Stub
    def initialize procedure
      @procedure = procedure
    end

    def and_return value
      @procedure.call value
    end
  end

  def override! method
    Stub.new(lambda do |value|
      alias_method "orig_#{method}", method
      define_method(method) { value }
    end)
  end

  def restore! method
    alias_method method, "orig_#{method}"
  end
end
