require 'stringio'

class String
  def strip_indentation
    ident = (to_a[0] =~ /[^\s]/)
    to_a.map {|x| x.slice(ident, x.size) }.to_s
  end
end

context "Module svntl" do
  include ContextHelper

  setup do
    @nonexisting_modules = []
    @ignored_modules = []

    Kernel.override!(:require).with do |name|
      if @nonexisting_modules.include? name
        raise LoadError.new("no such file to load -- #{name}")
      elsif not @ignored_modules.include? name
        orig_require name
      end
    end
  end

  teardown do
    Kernel.restore! :require
  end

  def stderr_of
    captured = StringIO.new
    orig_stderr, $stderr = $stderr, captured
    yield
    captured.rewind
    captured.read
  ensure
    $stderr = orig_stderr
  end

  specify "should not allow LoadError to be throw to user's face if gruff is not present" do
    @nonexisting_modules = ['gruff']
    lambda { stderr_of { without_exception(SystemExit) { load 'svntl.rb' } } }.should_not_raise LoadError
  end

  specify "should show nice info for user when gruff is not present" do
    @nonexisting_modules = ['gruff']
    expected = <<-EOV
      You don't seem to have Gruff library installed. It is needed for chart generation.
      To install with Ruby Gems:
        sudo gem install gruff
      If you don't have Gems, install manually from http://rubyforge.org/frs/?group_id=1044 .
    EOV

    stderr_of { without_exception(SystemExit) { load 'svntl.rb' } }.should == expected.strip_indentation
  end

  specify "should exit with error code 1 when gruff is not present" do
    @nonexisting_modules = ['gruff']
    lambda { stderr_of { load 'svntl.rb' } }.should_exit_with_code 1
  end

  specify "should not allow LoadError to be throw to user's face if open4 is not present" do
    @nonexisting_modules = ['open4']
    lambda { stderr_of { without_exception(SystemExit) { load 'svntl.rb' } } }.should_not_raise LoadError
  end

  specify "should show nice info for user when open4 is not present" do
    @nonexisting_modules = ['open4']
    expected = <<-EOV
      You don't seem to have Open4 library installed. It is needed for running `svn` command.
      To install with Ruby Gems:
        sudo gem install open4
      If you don't have Gems, install manually from http://rubyforge.org/frs/?group_id=1024 .
    EOV

    stderr_of { without_exception(SystemExit) { load 'svntl.rb' } }.should == expected.strip_indentation
  end

  specify "should exit with error code 1 when open4 is not present" do
    @nonexisting_modules = ['open4']
    lambda { stderr_of { load 'svntl.rb' } }.should_exit_with_code 1
  end

  specify "should not raise LoadError when rubygems are not present" do
    @nonexisting_modules = ['rubygems']
    @ignored_modules = ['gruff']

    lambda { stderr_of { load 'svntl.rb' } }.should_not_raise LoadError
  end

  specify "should silently ignore non-existent rubygems" do
    @nonexisting_modules = ['rubygems']
    @ignored_modules = ['gruff']

    stderr_of { load 'svntl.rb' }.should == ''
  end
end
