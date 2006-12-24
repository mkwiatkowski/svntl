# A way to override modules' methods.
#
# To make Kernel#system always return true, execute:
#   Kernel.override!(:system).and_return true
#
# You may also use block which will substitute the original method:
#   Kernel.override!(:system).with { |command| puts command }
#
# To restore the original Kernel#system, do:
#   Kernel.restore! :system
#

class Module
  class Stub
    def initialize &procedure
      @procedure = procedure
    end

    def and_return value
      @procedure.call lambda { value }
    end

    def with &block
      @procedure.call block
    end
  end

  def override! method
    Stub.new do |procedure|
      alias_method "orig_#{method}", method
      define_method(method) { |*args| procedure.call(*args) }
    end
  end

  def restore! method
    alias_method method, "orig_#{method}"
  end
end
