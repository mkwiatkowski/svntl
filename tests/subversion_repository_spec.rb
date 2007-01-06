require 'rubygems'
require 'builder'
require 'set'
require 'date'

require 'svntl'
include SvnTimeline

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
  def mock_svn url, options={}
    setup do
      repository_url = Regexp.escape url

      SubversionRepository.override!(:execute_command).with do |command|
        options = { :datetime => {}, :dont_exist_in_rev_0 => false, :entries => Hash.new({}), :loc => {} }.merge(options)

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
          revision = $1.to_i
          options[:entries][revision].values.first
        when /^svn cat -r(\d+) #{repository_url}\/(.*)$/
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

context "Non-existing repository" do
  mock_svn "file:///existing/repository"

  specify "should raise SubversionError(No such repository) during creation" do
    lambda { SubversionRepository.new "file:///do/not/exist" }.should_raise SubversionError, "No such repository."
  end
end

context "Existing repository" do
  mock_svn "file:///existing/repository"

  specify "should be created without errors" do
    lambda { SubversionRepository.new "file:///existing/repository" }.should_not_raise SubversionError
  end
end

context "Empty repository" do
  mock_svn "file:///existing/repository"

  setup do
    @repo = SubversionRepository.new "file:///existing/repository"
  end

  specify "should have zero revisions" do
    @repo.revisions.number.should == 0
  end
end

context "Repository with one revision" do
  mock_svn "file:///existing/repository",
           :loc => { 1 => 5 }

  setup do
    @repo = SubversionRepository.new "file:///existing/repository"
  end

  specify "should have one revision" do
    @repo.revisions.number.should == 1
  end

  specify "should return Revision object on revision(0)" do
    @repo.revision(0).should_be_an_instance_of Revision
  end

  specify "should return Revision object on revision(1)" do
    @repo.revision(1).should_be_an_instance_of Revision
  end

  specify "should raise SubversionError(No such revision) on revision(2)" do
    lambda { @repo.revision(2) }.should_raise SubversionError, "No such revision."
  end

  specify "should report 0 LOC for revision(0)" do
    @repo.revision(0).loc.should == 0
  end

  specify "should report 5 LOC for revision(1)" do
    @repo.revision(1).loc.should == 5
  end
end

context "Repository with three revisions" do
  mock_svn "file:///existing/repository",
           :loc => { 1 => 5, 2 => 13, 3 => 7 }

  setup do
    @repo = SubversionRepository.new "file:///existing/repository"
  end

  specify "should have three revisions" do
    @repo.revisions.number.should == 3
  end

  specify "should report 5 LOC for revision(1)" do
    @repo.revision(1).loc.should == 5
  end

  specify "should report 13 LOC for revision(2)" do
    @repo.revision(2).loc.should == 13
  end

  specify "should report 7 LOC for revision(3)" do
    @repo.revision(3).loc.should == 7
  end
end

context "Repository with five scattered revisions" do
  mock_svn "file:///existing/repository",
           :loc => { 3 => 10, 4 => 46, 10 => 32, 12 => 32, 13 => 34 }

  setup do
    @repo = SubversionRepository.new "file:///existing/repository"
  end

  specify "should have five revisions" do
    @repo.revisions.number.should == 5
  end

  specify "should report 10 LOC for revision(3)" do
    @repo.revision(3).loc.should == 10
  end

  specify "should report 46 LOC for revision(4)" do
    @repo.revision(4).loc.should == 46
  end

  specify "should report 32 LOC for revision(10)" do
    @repo.revision(10).loc.should == 32
  end

  specify "should report 32 LOC for revision(12)" do
    @repo.revision(12).loc.should == 32
  end

  specify "should report 34 LOC for revision(13)" do
    @repo.revision(13).loc.should == 34
  end

  specify "should raise SubversionError(No such revision) on revision(1)" do
    lambda { @repo.revision(1) }.should_raise SubversionError, "No such revision."
  end

  specify "should raise SubversionError(No such revision) on revision(5)" do
    lambda { @repo.revision(5) }.should_raise SubversionError, "No such revision."
  end
end

context "/trunk of repository with two revisions and two files" do
  mock_svn "file:///existing/repository/trunk",
           :dont_exist_in_rev_0 => true,
           :loc => { 1 => 12, 2 => 36 },
           :entries => { 1 => { 'README' => 4.lines_of_code, 'code.py' => 8.lines_of_code } }

  setup do
    @repo = SubversionRepository.new "file:///existing/repository/trunk"
  end

  specify "should report 12 LOC for revision(1)" do
    @repo.revision(1).loc.should == 12
  end

  specify "should report 36 LOC for revision(2)" do
    @repo.revision(2).loc.should == 36
  end
end

context "/trunk of repository with one revision and one file" do
  mock_svn "file:///existing/repository/trunk",
           :dont_exist_in_rev_0 => true,
           :loc => { 1 => 4 },
           :entries => { 1 => { 'README' => 4.lines_of_code } }

  setup do
    @repo = SubversionRepository.new "file:///existing/repository/trunk"
  end

  specify "should report 4 LOC for revision(1)" do
    @repo.revision(1).loc.should == 4
  end
end

context "/trunk of repository with three empty revisions" do
  mock_svn "file:///existing/repository/trunk",
           :dont_exist_in_rev_0 => true,
           :loc => { 1 => 0, 2 => 0, 5 => 0 }

  setup do
    @repo = SubversionRepository.new "file:///existing/repository/trunk"
  end

  specify "should report 0 LOC for revision(1)" do
    @repo.revision(1).loc.should == 0
  end

  specify "should report 0 LOC for revision(2)" do
    @repo.revision(2).loc.should == 0
  end

  specify "should report 0 LOC for revision(5)" do
    @repo.revision(5).loc.should == 0
  end
end

context "Repository with three revisions of empty files" do
  mock_svn "file:///existing/repository",
           :loc => { 1 => 0, 3 => 0, 5 => 0 },
           :entries => { 1 => {},
                         2 => { 'README' => '', 'INSTALL' => '' },
                         3 => { 'README' => '', 'INSTALL' => '', 'code.py' => '' } }

  setup do
    @repo = SubversionRepository.new "file:///existing/repository"
  end

  specify "should report 0 LOC for revision(1)" do
    @repo.revision(1).loc.should == 0
  end

  specify "should report 0 LOC for revision(3)" do
    @repo.revision(3).loc.should == 0
  end

  specify "should report 0 LOC for revision(5)" do
    @repo.revision(5).loc.should == 0
  end
end

context "Repository with two revisions, one from 28 Dec 2006, other from 6 Mar 2005" do
  mock_svn "file:///existing/repository",
           :datetime => { 1 => Date.new(2006, 12, 28), 2 => Date.new(2005, 3, 6) }

  setup do
    @repo = SubversionRepository.new "file:///existing/repository"
  end

  specify "should report 28 Dec 2006 date of revision(1)" do
    @repo.revision(1).date.should == Date.new(2006, 12, 28)
  end

  specify "should report 6 Mar 2005 date of revision(2)" do
    @repo.revision(2).date.should == Date.new(2005, 3, 6)
  end
end

context "File in a repository" do
  mock_svn "file:///existing/repository/trunk/module.rb",
           :dont_exist_in_rev_0 => true,
           :loc => { 1 => 10 },
           :entries => { 1 => { 'module.rb' => 10.lines_of_code } }

  specify "should not raise SubversionError on SubversionRepository.new" do
    lambda { @repo = SubversionRepository.new "file:///existing/repository/trunk/module.rb" }.should_not_raise SubversionError
  end

  specify "should report 10 LOC for revision(1)" do
    @repo = SubversionRepository.new "file:///existing/repository/trunk/module.rb"
    @repo.revision(1).loc.should == 10
  end
end
