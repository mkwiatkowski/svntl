require 'stringio'

class String
  def strip_indentation
    ident = (to_a[0] =~ /[^\s]/)
    to_a.map {|x| x.slice(ident, x.size) }.to_s
  end
end

context "Module svntl" do
  setup do
    Kernel.override!(:require).with do |name|
      if name == 'gruff'
        raise LoadError.new('no such file to load -- gruff')
      else
        orig_require name
      end
    end
  end

  teardown do
    Kernel.restore! :require
  end

  def capture_stderr
    orig_stderr = $stderr
    begin
      captured = StringIO.new
      $stderr = captured
      yield
    ensure
      $stderr = orig_stderr
    end
    captured.rewind
    captured.read
  end

  specify "should not allow LoadError to be throw to user's face if gruff is not present" do
    lambda { capture_stderr { load 'svntl.rb' } }.should_not_raise LoadError
  end

  specify "should show nice info for user when gruff is not present" do
    expected = <<-EOV
      You don't seem to have Gruff library installed. It is needed for chart generation.
      To install with Ruby Gems:
        sudo gem install gruff
      If you don't have Gems, install manually from http://rubyforge.org/frs/?group_id=1044 .
    EOV

    stderr = capture_stderr { load 'svntl.rb' }
    stderr.should == expected.strip_indentation
  end
end
