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

######################################################################
# Implementation of mock_svn context method.
class Array
  def insert_at_random *obj
    insert(rand(size+1), *obj)
  end
end

class Integer
  def lines_of_code
    "a line of code\n" * self
  end
end

def keys_of *hashes
  hashes.inject([]) { |all_keys, hash| all_keys.concat hash.keys }.to_set
end

module Spec::Runner::ContextEval::ModuleMethods
  # Mock Subversion behaviour by overriding execute_command method.
  def mock_svn url, options={}
    setup do
      repository_url = Regexp.escape url

      SubversionRepository.override!(:execute_command).with do |command|
        options = { :datetime => {}, :entries => Hash.new({}), :loc => {} }.merge(options)

        case command
        when /^svn diff -r(\d+):(\d+) --diff-cmd "diff" -x "--normal" #{repository_url}$/
          if $1.to_i == 0 and options[:dont_exist_in_rev_0]
            raise IOError
          end

          # Each repository have implicit revision 0 with 0 LOC.
          loc = options[:loc].merge({ 0 => 0 })
          loc_start = (loc[$1.to_i] or 0)
          loc_end = (loc[$2.to_i] or 0)

          diff_document = ""

          if loc_start != loc_end
            loc_start.times { diff_document << "< what goes away\n" }
            loc_end.times { diff_document << "> what goes in\n" }

            # Insert few diff context lines to ensure that they're ignored.
            rand(3).times { diff_document = diff_document.to_a.insert_at_random("1,2c1,6\n").to_s }
            rand(3).times { diff_document = diff_document.to_a.insert_at_random("---\n").to_s }
          end

          diff_document
        when /^svn log --xml #{repository_url}$/
          xml_document = ""

          xml = Builder::XmlMarkup.new :target => xml_document
          xml.instruct!
          xml.log do
            keys_of(options[:loc], options[:datetime]).sort.each do |rev|
              xml.logentry :revision => rev do
                xml.author "ruby"
                xml.date(if options[:datetime][rev]
                           options[:datetime][rev].strftime("%FT%T.000000%Z")
                         else
                           "2006-12-13T12:13:14.123456Z"
                         end)
                xml.msg "Bugfixes."
              end
            end
          end

          xml_document
        when /^svn ls -R --xml -r(\d+) #{repository_url}$/
          revision = $1.to_i
          files_in_revision = options[:entries][revision].keys

          xml_document = ""

          xml = Builder::XmlMarkup.new :target => xml_document
          xml.instruct!
          xml.lists do
            xml.list :path => repository_url do
              files_in_revision.each do |file|
                xml.entry :kind => 'file' do 
                  xml.name file
                  xml.commit :revision => revision do
                    xml.date "2006-12-13T12:13:14.123456Z"
                  end
                end
              end
            end
          end

          xml_document
        when /^svn cat -r(\d+) #{repository_url}$/
          raise IOError unless options[:url_points_to_file]
          revision = $1.to_i
          options[:entries][revision].values.first
        when /^svn cat -r(\d+) #{repository_url}\/(.*)$/
          raise IOError if options[:url_points_to_file]
          filename = $2
          revision = $1.to_i
          options[:entries][revision][filename] or raise IOError
        else
          raise IOError
        end
      end
    end

    teardown do
      SubversionRepository.restore! :execute_command
    end
  end
end

######################################################################
# Implementation of should_exit_with_code expectation.
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

######################################################################
# ContextHelper module for inclusion within contexts.
module ContextHelper
  def without_exception ex
    yield
  rescue ex
    nil
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
