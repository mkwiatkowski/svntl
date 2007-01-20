require 'svntl'
include SvnTimeline

context "Method generate_charts" do
  mock_svn 'file:///existing/repository'

  setup do
    Dir.stub!(:mkdir)

    @repo = SubversionRepository.new 'file:///existing/repository'

    # Make generate_charts public to allow direct testing.
    class << @repo ; public :generate_charts ; end

    @gruff_line_object = mock "gruff_line_object", :null_object => true
    Gruff::Line.stub!(:new).and_return(@gruff_line_object)
  end

  specify "should call each chart generation method twice with `file` argument set to `timeline/loc_per_commit.png`, once setting `small` to true" do
    @repo.should_receive(:chart_loc_per_commit).once.with(:file => 'timeline/loc_per_commit.png')
    @repo.should_receive(:chart_loc_per_commit).once.with(:file => 'timeline/loc_per_commit_small.png', :small => true)
    @repo.should_receive(:chart_loc_per_day).once.with(:file => 'timeline/loc_per_day.png')
    @repo.should_receive(:chart_loc_per_day).once.with(:file => 'timeline/loc_per_day_small.png', :small => true)

    @repo.generate_charts 'timeline'
  end

  specify "should accept `title` argument and pass it to each chart generation method" do
    @repo.should_receive(:chart_loc_per_commit).once.with(:title => 'My Repository', :file => 'timeline/loc_per_commit.png')
    @repo.should_receive(:chart_loc_per_commit).once.with(:title => 'My Repository', :file => 'timeline/loc_per_commit_small.png', :small => true)
    @repo.should_receive(:chart_loc_per_day).once.with(:title => 'My Repository', :file => 'timeline/loc_per_day.png')
    @repo.should_receive(:chart_loc_per_day).once.with(:title => 'My Repository', :file => 'timeline/loc_per_day_small.png', :small => true)

    @repo.generate_charts 'timeline', :title => 'My Repository'
  end

  specify "should call chart generation methods with `file` argument equal to `dir\\chart.png` in systems which has backslash as directory separator" do
    begin
      File.stub!(:exist?).and_return(false)
      File.metaclass.override!(:join).with do |*strings|
        strings.join("\\")
      end

      @repo.should_receive(:chart_loc_per_commit).once.with(:file => 'dir\loc_per_commit.png')
      @repo.should_receive(:chart_loc_per_commit).once.with(:file => 'dir\loc_per_commit_small.png', :small => true)
      @repo.should_receive(:chart_loc_per_day).once.with(:file => 'dir\loc_per_day.png')
      @repo.should_receive(:chart_loc_per_day).once.with(:file => 'dir\loc_per_day_small.png', :small => true)

      @repo.generate_charts 'dir'

    ensure
      File.metaclass.restore! :join
    end
  end
end
