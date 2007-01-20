require 'svntl'
include SvnTimeline

context "Method generate_charts" do
  mock_svn 'file:///existing/repository'

  setup do
    @repo = SubversionRepository.new 'file:///existing/repository'

    @gruff_line_object = mock "gruff_line_object", :null_object => true
    Gruff::Line.stub!(:new).and_return(@gruff_line_object)
  end

  specify "should create directory timeline/ if repository exists" do
    File.stub!(:exist?).and_return(false)
    Dir.should_receive(:mkdir).with('timeline')

    @repo.generate_charts
  end

  specify "should not try to create existing timeline/ directory" do
    File.stub!(:exist?).and_return(true)
    Dir.should_not_receive(:mkdir)

    @repo.generate_charts
  end

  specify "should call each chart generation method twice with `file` argument set to `timeline/loc_per_commit.png`, once setting `small` to true" do
    Dir.stub!(:mkdir)
    @repo.should_receive(:chart_loc_per_commit).once.with(:file => 'timeline/loc_per_commit.png')
    @repo.should_receive(:chart_loc_per_commit).once.with(:file => 'timeline/loc_per_commit_small.png', :small => true)
    @repo.should_receive(:chart_loc_per_day).once.with(:file => 'timeline/loc_per_day.png')
    @repo.should_receive(:chart_loc_per_day).once.with(:file => 'timeline/loc_per_day_small.png', :small => true)

    @repo.generate_charts
  end

  specify "should accept `title` argument and pass it to each chart generation method" do
    Dir.stub!(:mkdir)

    @repo.should_receive(:chart_loc_per_day).once.with(:title => 'My Repository', :file => 'timeline/loc_per_day.png')
    @repo.should_receive(:chart_loc_per_day).once.with(:title => 'My Repository', :file => 'timeline/loc_per_day_small.png', :small => true)
    @repo.should_receive(:chart_loc_per_commit).once.with(:title => 'My Repository', :file => 'timeline/loc_per_commit.png')
    @repo.should_receive(:chart_loc_per_commit).once.with(:title => 'My Repository', :file => 'timeline/loc_per_commit_small.png', :small => true)

    @repo.generate_charts :title => 'My Repository'
  end

  specify "should create named directory if `directory` argument was passed" do 
    File.stub!(:exist?).and_return(false)
    Dir.should_receive(:mkdir).with('svntl')

    @repo.generate_charts :directory => 'svntl'
  end

  specify "should call chart generation methods with `file` argument equal to `dir\\chart.png` in systems which has backslash as directory separator" do
    begin
      File.stub!(:exist?).and_return(false)
      File.metaclass.override!(:join).with do |*strings|
        strings.join("\\")
      end
      Dir.stub!(:mkdir)

      @repo.should_receive(:chart_loc_per_day).once.with(:file => 'dir\loc_per_day.png')
      @repo.should_receive(:chart_loc_per_day).once.with(:file => 'dir\loc_per_day_small.png', :small => true)
      @repo.should_receive(:chart_loc_per_commit).once.with(:file => 'dir\loc_per_commit.png')
      @repo.should_receive(:chart_loc_per_commit).once.with(:file => 'dir\loc_per_commit_small.png', :small => true)

      @repo.generate_charts :directory => 'dir'

    ensure
      File.metaclass.restore! :join
    end
  end
end
