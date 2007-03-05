require 'fileutils'
require 'stringio'

require 'svntl'
include SvnTimeline

module Spec::Runner::ContextEval::ModuleMethods
  def common_generate_statistics_setup
    setup do
      @repo = SubversionRepository.new 'file:///existing/repository'
      @repo.stub!(:generate_charts)
      @repo.stub!(:generate_html)

      File.stub!(:open).and_yield(StringIO.new)
    end
  end
end

context "Method generate_statistics for existing timeline/ directory" do
  mock_svn 'file:///existing/repository'
  common_generate_statistics_setup

  specify "should not try to create existing timeline/ directory" do
    File.stub!(:exist?).and_return(true)

    Dir.should_not_receive(:mkdir)

    @repo.generate_statistics
  end

end

context "Method generate_statistics for non-existing timeline/ directory" do
  mock_svn 'file:///existing/repository'
  common_generate_statistics_setup

  setup do
    File.stub!(:exist?).and_return(false)
    Dir.stub!(:mkdir)
  end

  specify "should create directory timeline/ if it don't exist" do
    Dir.should_receive(:mkdir).with('timeline')

    @repo.generate_statistics
  end

  specify "should create named `svntl` if `directory` argument was passed" do 
    Dir.should_receive(:mkdir).with('svntl')

    @repo.generate_statistics 'svntl'
  end

  specify "should call generate_charts method" do
    @repo.should_receive(:generate_charts)

    @repo.generate_statistics
  end

  specify "should pass `directory` argument to generate_charts method" do
    @repo.should_receive(:generate_charts).with('svntl')

    @repo.generate_statistics 'svntl'
  end

  specify "should call generate_html method" do
    @repo.should_receive(:generate_html)

    @repo.generate_statistics
  end

  specify "should pass `directory` argument to generate_html method" do
    @repo.should_receive(:generate_html).with('svntl')

    @repo.generate_statistics 'svntl'
  end

  specify "should copy 'moo.fx.js', 'moo.fx.pack.js' and 'prototype.lite.js' into destionation directory" do
    FileUtils.should_receive(:copy).with('templates/moo.fx.js', 'timeline')
    FileUtils.should_receive(:copy).with('templates/moo.fx.pack.js', 'timeline')
    FileUtils.should_receive(:copy).with('templates/prototype.lite.js', 'timeline')

    @repo.generate_statistics
  end
end
