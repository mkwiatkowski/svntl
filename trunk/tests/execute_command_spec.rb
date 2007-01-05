require 'svntl'
require 'stringio'
include SvnTimeline

context "execute_command" do
  def redefine_constant(mod, const, value)
    mod.module_eval do
      remove_const(const) if mod.const_defined? const
    end
    mod.const_set(const, value)
  end

  setup do
    redefine_constant Object, :Open4, mock('open4')
  end

  def successful_process
    Process.waitpid(fork { exit(0) })
  end

  def failed_process
    Process.waitpid(fork { exit(1) })
  end

  specify "should have printed nothing for 'true'" do
    Open4.should_receive(:popen4).with('true').and_yield(successful_process, '', StringIO.new(''), '')
    execute_command("true").should == ''
  end

  specify "should not raise IOError for 'true'" do
    Open4.should_receive(:popen4).with('true').and_yield(successful_process, '', StringIO.new(''), '')
    lambda { execute_command("true") }.should_not_raise IOError
  end

  specify "should raise IOError for 'false'" do
    Open4.should_receive(:popen4).with('false').and_yield(failed_process, '', StringIO.new(''), '')
    lambda { execute_command("false")}.should_raise IOError
  end

  specify "should output 'Hello world!' for 'hello'" do
    Open4.should_receive(:popen4).with('hello').and_yield(successful_process, '', StringIO.new('Hello world!'), '')
    execute_command("hello").should == 'Hello world!'
  end
end
