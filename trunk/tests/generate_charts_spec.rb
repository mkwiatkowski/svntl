require 'svntl'
include SvnTimeline

context "generate_charts method for non-existing repository" do
  include ContextHelper

  setup do
    SubversionRepository.stub!(:new).and_raise(SubversionError.new("No such repository."))
  end

  specify "should not create any directory" do
    Dir.should_not_receive(:mkdir)
    without_exception(SubversionError) { generate_charts 'file:///do/not/exist' }
  end

  specify "should raise SubversionError(No such repository) during call" do
    lambda { generate_charts 'file:///do/not/exist' }.should_raise SubversionError, "No such repository."
  end
end

context "generate_charts method for existing repository" do
  setup do
    @repository_object = mock 'subversion_repository_object', :null_object => true
    SubversionRepository.stub!(:new).and_return(@repository_object)
  end

  specify "should create directory timeline/ if repository exists" do
    File.stub!(:exist?).and_return(false)
    Dir.should_receive(:mkdir).with('timeline')

    generate_charts 'file:///existing/repository'
  end

  specify "should not try to create existing timeline/ directory" do
    File.stub!(:exist?).and_return(true)
    Dir.should_not_receive(:mkdir)

    generate_charts 'file:///existing/repository'
  end

  specify "should once call chart_loc_per_commit with `file` argument set to `timeline/loc_per_commit.png`" do
    Dir.stub!(:mkdir)
    @repository_object.should_receive(:chart_loc_per_commit).once.with(:file => 'timeline/loc_per_commit.png')

    generate_charts 'file:///existing/repository'
  end

  specify "should once call chart_loc_per_commit with `file` argument set to `timeline/loc_per_commit_small.png` and `small` set to `true`" do
    Dir.stub!(:mkdir)
    @repository_object.should_receive(:chart_loc_per_commit).once.with(:file => 'timeline/loc_per_commit_small.png', :small => true)

    generate_charts 'file:///existing/repository'
  end

  specify "should once call chart_loc_per_day with `file` argument set to `timeline/loc_per_day.png`" do
    Dir.stub!(:mkdir)
    @repository_object.should_receive(:chart_loc_per_day).once.with(:file => 'timeline/loc_per_day.png')

    generate_charts 'file:///existing/repository'
  end

  specify "should once call chart_loc_per_day with `file` argument set to `timeline/loc_per_day_small.png` and `small` set to `true`" do
    Dir.stub!(:mkdir)
    @repository_object.should_receive(:chart_loc_per_day).once.with(:file => 'timeline/loc_per_day_small.png', :small => true)

    generate_charts 'file:///existing/repository'
  end

  specify "should accept `title` argument and pass it to each chart generation method" do
    Dir.stub!(:mkdir)
    @repository_object.should_receive(:chart_loc_per_day).once.with(:title => 'My Repository', :file => 'timeline/loc_per_day.png')
    @repository_object.should_receive(:chart_loc_per_day).once.with(:title => 'My Repository', :file => 'timeline/loc_per_day_small.png', :small => true)
    @repository_object.should_receive(:chart_loc_per_commit).once.with(:title => 'My Repository', :file => 'timeline/loc_per_commit.png')
    @repository_object.should_receive(:chart_loc_per_commit).once.with(:title => 'My Repository', :file => 'timeline/loc_per_commit_small.png', :small => true)

    generate_charts 'file:///existing/repository', :title => 'My Repository'
  end
end
