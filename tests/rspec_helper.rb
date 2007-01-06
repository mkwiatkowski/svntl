require 'svntl'
include SvnTimeline

class SubversionRepositoryMock < SubversionRepository
  attr_accessor :url, :revisions, :last_revision
  def initialize
    @revisions = ListOfRevisions.new
    @initial_date = Date.today
  end

  def revisions_append_with_loc loc
    loc.each_with_index do |loc, idx|
      @revisions << Revision.new(idx+1, :loc => loc, :date => uniq_date)
    end
  end

  def revisions_append_with_date dates
    dates.each_with_index do |date, idx|
      # Setting LOC as well because svntl ignores leading revisions with zero LOC.
      @revisions << Revision.new(idx+1, :loc => 1, :date => date)
    end
  end

  private
  def uniq_date
    @initial_date += 1
  end
end

module Spec::Expectations::ProcExpectations
  def should_exit_with_code code
    should_satisfy do |proc|
      begin
        proc.call
        false
      rescue SystemExit => ex
        ex.status.should == code
        true
      end
    end
  end
end

module Spec::Runner::ContextEval::ModuleMethods
  def chart_spec options={}
    setup do
      @repo = SubversionRepositoryMock.new

      @gruff_line_object = mock "gruff_line_object", :null_object => true
      Gruff::Line.stub!(:new).and_return(@gruff_line_object)
    end

    specify "should call Gruff::Line.new to generate chart" do
      Gruff::Line.should_receive(:new).with(:no_args).and_return(@gruff_line_object)

      @repo.send(options[:method])
    end

    specify "should call chart.data('LOC', []) for empty repository" do
      @gruff_line_object.should_receive(:data).with('LOC', [])

      @repo.send(options[:method])
    end

    specify "should call chart.data('LOC', [12]) for repository with one revision that have 12 LOC" do
      @repo.revisions_append_with_loc [12]
      @gruff_line_object.should_receive(:data).with('LOC', [12])

      @repo.send(options[:method])
    end

    specify "should call chart.data('LOC', [3, 7, 13] for repository with three revisions of 3, 7 and 13 LOC" do
      @repo.revisions_append_with_loc [3, 7, 13]
      @gruff_line_object.should_receive(:data).with('LOC', [3, 7, 13])

      @repo.send(options[:method])
    end

    specify "should ignore leading repositories with zero LOC when calling chart.data" do
      @repo.revisions_append_with_loc [0, 0, 1, 2, 3]
      @gruff_line_object.should_receive(:data).with('LOC', [1, 2, 3])

      @repo.send(options[:method])
    end

    specify "should set title to repository url by default" do
      @repo.url = 'some repository URL'
      @gruff_line_object.should_receive(:title=).with(@repo.url)

      @repo.send(options[:method])
    end

    specify "should call chart.title with given title if :title argument is present" do
      @gruff_line_object.should_receive(:title=).with('some nice title')

      @repo.send(options[:method], :title => 'some nice title')
    end

    specify "should save chart to loc.png by default" do
      @gruff_line_object.should_receive(:write).with('loc.png')

      @repo.send(options[:method])
    end

    specify "should save chart to given file if :file arguments is present" do
      @gruff_line_object.should_receive(:write).with('output.png')

      @repo.send(options[:method], :file => 'output.png')
    end

    specify "should hide dots on chart" do
      @gruff_line_object.should_receive(:hide_dots=).with(true)

      @repo.send(options[:method])
    end

    specify "should hide legend" do
      @gruff_line_object.should_receive(:hide_legend=).with(true)

      @repo.send(options[:method])
    end

    specify "should use marker font size of 10" do
      @gruff_line_object.should_receive(:marker_font_size=).with(10)

      @repo.send(options[:method])
    end

    specify "should create 200px width chart when :small argument is present" do
      Gruff::Line.should_receive(:new).with(200).and_return(@gruff_line_object)

      @repo.send(options[:method], :small => true)
    end

    specify "should not hide line markers by default" do
      @gruff_line_object.should_not_receive(:hide_line_markers=).with(true)

      @repo.send(options[:method])
    end

    specify "should hide line markers when :small argument is present" do
      @gruff_line_object.should_receive(:hide_line_markers=).with(true)

      @repo.send(options[:method], :small => true)
    end

    specify "should not set title font size to 50 by default" do
      @gruff_line_object.should_not_receive(:title_font_size=).with(50)

      @repo.send(options[:method])
    end

    specify "should set title font size to 50 when :small argument is present" do
      @gruff_line_object.should_receive(:title_font_size=).with(50)

      @repo.send(options[:method], :small => true)
    end
  end
end

module ContextHelper
  def without_exception ex
    yield
  rescue ex
    nil
  end
end
