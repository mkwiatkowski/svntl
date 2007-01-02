require 'rubygems'
require 'gruff'

context "Method chart_loc_per_commit" do
  chart_spec :method => :chart_loc_per_commit

  specify "should use at most 20 labels" do
    @repo.revisions_append_with_loc((1..50).to_a)
    @gruff_line_object.should_receive(:labels=) do |labels|
      labels.size.should <= 20
    end

    @repo.chart_loc_per_commit
  end

  specify "should use exactly 20 lables for repository with 60 revisions" do
    @repo.revisions_append_with_loc((1..60).to_a)
    @gruff_line_object.should_receive(:labels=) do |labels|
      labels.size.should == 20
    end

    @repo.chart_loc_per_commit
  end

  specify "should set labels to {0=>\"1\"} for repository with one non-empty revision" do
    @repo.revisions_append_with_loc [2]
    @gruff_line_object.should_receive(:labels=).with({ 0=>"1" })

    @repo.chart_loc_per_commit
  end

  specify "should set labels according to revision numbers" do
    @repo.revisions_append_with_loc [1, 2, 3, 4, 5]
    labels = { 0=>"1", 1=>"2", 2=>"3", 3=>"4", 4=>"5" }
    @gruff_line_object.should_receive(:labels=).with(labels)

    @repo.chart_loc_per_commit
  end

  specify "should set labels to {0=>\"9\", 1=>\"10\"} for repository with non-empty revisions 9 and 10" do
    @repo.revisions << Revision.new(9, :loc => 1)
    @repo.revisions << Revision.new(10, :loc => 1)
    @gruff_line_object.should_receive(:labels=).with({0=>"9", 1=>"10"})

    @repo.chart_loc_per_commit
  end
end
