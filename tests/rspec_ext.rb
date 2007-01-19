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
# When you want to override a class method, use metaclass helper:
#   File.metaclass.override!(:open).with { |filename, mode| puts "Opening #{filename} in #{mode}." }
#
# Remember to restore with metaclass as well:
#   File.metaclass.restore! :open
#

class Module
  class Stub
    def initialize &procedure
      @procedure = procedure
    end

    def with &block
      @procedure.call block
    end

    def and_return value
      @procedure.call lambda {  value }
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

class Object
  def metaclass
    class << self; self; end
  end
end
