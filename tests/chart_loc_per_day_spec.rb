require 'rubygems'
require 'gruff'
require 'date'

context "Method chart_loc_per_day" do
  chart_spec :method => :chart_loc_per_day

  specify "should use at most 10 labels" do
    @repo.revisions_append_with_loc((1..53).to_a)
    @gruff_line_object.should_receive(:labels=) do |labels|
      labels.size.should <= 10
    end

    @repo.chart_loc_per_day
  end

  specify "should use exactly 10 lables for repository with 40 revisions" do
    @repo.revisions_append_with_loc((1..40).to_a)
    @gruff_line_object.should_receive(:labels=) do |labels|
      labels.size.should == 10
    end

    @repo.chart_loc_per_day
  end

  specify "should set labels to {0=>\"2006-11-12\"} for repository with one non-empty revision from 12 Nov 2006" do
    @repo.revisions_append_with_date [ Date.new(2006, 11, 12) ]
    @gruff_line_object.should_receive(:labels=).with({ 0=>"2006-11-12" })

    @repo.chart_loc_per_day
  end

  specify "should set labels to {0=>\"2006-01-27\"} for repository with three non-empty revisions from 27 Jan 2006" do
    @repo.revisions_append_with_date [ Date.new(2006, 1, 27), Date.new(2006, 1, 27), Date.new(2006, 1, 27) ]
    @gruff_line_object.should_receive(:labels=).with({ 0=>"2006-01-27" })

    @repo.chart_loc_per_day
  end

  specify "should set labels to {0=>\"2005-02-14\"} for repository with two revisions, first empty from 13 Feb 2005, second not empty from 14 Feb 2005" do
    @repo.revisions << Revision.new(1, :loc => 0, :date => Date.new(2005, 2, 13))
    @repo.revisions << Revision.new(2, :loc => 14, :date => Date.new(2005, 2, 14))
    @gruff_line_object.should_receive(:labels=).with({ 0=>"2005-02-14" })

    @repo.chart_loc_per_day
  end

  specify "should call chart.data('LOC', [18]) for repository with two revisions commited on the same day with first having 5 LOC and second 18 LOC" do
    @repo.revisions << Revision.new(1, :loc => 5, :date => Date.new(2007, 1, 1))
    @repo.revisions << Revision.new(2, :loc => 18, :date => Date.new(2007, 1, 1))
    @gruff_line_object.should_receive(:data).with('LOC', [18])

    @repo.chart_loc_per_day
  end
end
