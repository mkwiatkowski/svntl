require 'stringio'

class String
  def strip_indentation
    ident = (to_a[0] =~ /[^\s]/)
    to_a.map {|x| x.slice(ident, x.size) }.to_s
  end
end

context "Module svntl" do
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

  def capture_stderr
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
    lambda { capture_stderr { load 'svntl.rb' } }.should_not_raise LoadError
  end

  specify "should show nice info for user when gruff is not present" do
    @nonexisting_modules = ['gruff']
    expected = <<-EOV
      You don't seem to have Gruff library installed. It is needed for chart generation.
      To install with Ruby Gems:
        sudo gem install gruff
      If you don't have Gems, install manually from http://rubyforge.org/frs/?group_id=1044 .
    EOV

    stderr = capture_stderr { load 'svntl.rb' }
    stderr.should == expected.strip_indentation
  end

  specify "should not raise LoadError when rubygems are not present" do
    @nonexisting_modules = ['rubygems']
    @ignored_modules = ['gruff']

    lambda { capture_stderr { load 'svntl.rb' } }.should_not_raise LoadError
  end

  specify "should silently ignore non-existent rubygems" do
    @nonexisting_modules = ['rubygems']
    @ignored_modules = ['gruff']

    stderr = capture_stderr { load 'svntl.rb' }
    stderr.should == ''
  end
end
