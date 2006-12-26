require 'rubygems'
require 'gruff'

require 'svntl'
include SvnTimeline

class SubversionRepositoryMock < SubversionRepository
  attr_accessor :url, :revisions, :last_revision
  def initialize
    @revisions = [ Revision.new(0) ]
  end

  def revisions_append loc
    loc.each_with_index do |loc, idx|
      @revisions << Revision.new(idx+1, loc)
    end
  end
end

context "Method chart_loc_per_commit" do
  setup do
    @repo = SubversionRepositoryMock.new

    @gruff_line_object = mock "gruff_line_object", :null_object => true
    Gruff::Line.stub!(:new).and_return(@gruff_line_object)
  end

  specify "should call Gruff::Line.new to generate chart" do
    Gruff::Line.should_receive(:new).with(:no_args).and_return(@gruff_line_object)

    @repo.chart_loc_per_commit
  end

  specify "should call chart.data('LOC', []) for empty repository" do
    @gruff_line_object.should_receive(:data).with('LOC', [])

    @repo.chart_loc_per_commit
  end

  specify "should call chart.data('LOC', [12]) for repository with one revision that have 12 LOC" do
    @repo.revisions_append [12]
    @gruff_line_object.should_receive(:data).with('LOC', [12])

    @repo.chart_loc_per_commit
  end

  specify "should call chart.data('LOC', [3, 7, 13] for repository with three revisions of 3, 7 and 13 LOC" do
    @repo.revisions_append [3, 7, 13]
    @gruff_line_object.should_receive(:data).with('LOC', [3, 7, 13])

    @repo.chart_loc_per_commit
  end

  specify "should ignore leading repositories with zero LOC when calling chart.data" do
    @repo.revisions_append [0, 0, 1, 2, 3]
    @gruff_line_object.should_receive(:data).with('LOC', [1, 2, 3])

    @repo.chart_loc_per_commit
  end

  specify "should set title to repository url by default" do
    @repo.url = 'some repository URL'
    @gruff_line_object.should_receive(:title=).with(@repo.url)

    @repo.chart_loc_per_commit
  end

  specify "should call chart.title with given title if :title argument is present" do
    @gruff_line_object.should_receive(:title=).with('some nice title')

    @repo.chart_loc_per_commit :title => 'some nice title'
  end

  specify "should set labels to {0=>\"1\"} for repository with one non-empty revision" do
    @repo.revisions_append [2]
    @gruff_line_object.should_receive(:labels=).with({ 0=>"1" })

    @repo.chart_loc_per_commit
  end

  specify "should set labels according to revision numbers" do
    @repo.revisions_append [1, 2, 3, 4, 5]
    labels = { 0=>"1", 1=>"2", 2=>"3", 3=>"4", 4=>"5" }
    @gruff_line_object.should_receive(:labels=).with(labels)

    @repo.chart_loc_per_commit
  end

  specify "should not use at most 20 labels" do
    @repo.revisions_append((1..50).to_a)
    @gruff_line_object.should_receive(:labels=) do |labels|
      labels.size.should <= 20
    end

    @repo.chart_loc_per_commit
  end

  specify "should use exactly 20 lables for repository with 60 revisions" do
    @repo.revisions_append((1..60).to_a)
    @gruff_line_object.should_receive(:labels=) do |labels|
      labels.size.should == 20
    end

    @repo.chart_loc_per_commit
  end

  specify "should save chart to loc.png by default" do
    @gruff_line_object.should_receive(:write).with('loc.png')

    @repo.chart_loc_per_commit
  end

  specify "should save chart to given file if :file arguments is present" do
    @gruff_line_object.should_receive(:write).with('output.png')

    @repo.chart_loc_per_commit :file => 'output.png'
  end

  specify "should hide dots on chart" do
    @gruff_line_object.should_receive(:hide_dots=).with(true)

    @repo.chart_loc_per_commit
  end

  specify "should hide legend" do
    @gruff_line_object.should_receive(:hide_legend=).with(true)

    @repo.chart_loc_per_commit
  end

  specify "should use marker font size of 10" do
    @gruff_line_object.should_receive(:marker_font_size=).with(10)

    @repo.chart_loc_per_commit
  end

  specify "should create 200px width chart when :small argument is present" do
    Gruff::Line.should_receive(:new).with(200).and_return(@gruff_line_object)

    @repo.chart_loc_per_commit :small => true
  end

  specify "should not hide line markers by default" do
    @gruff_line_object.should_not_receive(:hide_line_markers=).with(true)

    @repo.chart_loc_per_commit
  end

  specify "should hide line markers when :small argument is present" do
    @gruff_line_object.should_receive(:hide_line_markers=).with(true)

    @repo.chart_loc_per_commit :small => true
  end

  specify "should not set title font size to 50 by default" do
    @gruff_line_object.should_not_receive(:title_font_size=).with(50)

    @repo.chart_loc_per_commit
  end

  specify "should set title font size to 50 when :small argument is present" do
    @gruff_line_object.should_receive(:title_font_size=).with(50)

    @repo.chart_loc_per_commit :small => true
  end
end
