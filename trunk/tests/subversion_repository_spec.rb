require 'rubygems'
require 'builder'

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

module Spec::Runner::ContextEval::ModuleMethods
  def mock_svn options={}
    setup do
      SubversionRepository.override!(:execute_command).with do |command|
        options = { :loc => {}, :entries => Hash.new({}) }.merge!(options)
        existing_root_url = 'file:///existing/repository'
        existing_trunk_url = "#{existing_root_url}/trunk"

        case command
        when "svn diff -r0:1 --diff-cmd \"diff\" -x \"--normal\" #{existing_trunk_url}"
            # "trunk/" didn't exist during rev. 0, thus we're raising an exception.
            raise IOError
        when /svn diff -r(\d+):(\d+) --diff-cmd "diff" -x "--normal" #{existing_trunk_url}/,
             /svn diff -r(\d+):(\d+) --diff-cmd "diff" -x "--normal" #{existing_root_url}/
          # Each repository have implicit revision no 0 with 0 LOC.
          loc = options[:loc].merge!({ 0 => 0 })
          loc_start, loc_end = loc[$1.to_i], loc[$2.to_i]

          diff_document = ""

          if loc_start != loc_end
            loc_start.times { diff_document << "< what goes away\n" }
            loc_end.times { diff_document << "> what goes in\n" }

            # Insert few diff context lines to ensure that they're ignored.
            rand(3).times { diff_document = diff_document.to_a.insert_at_random("1,2c1,6\n").to_s }
            rand(3).times { diff_document = diff_document.to_a.insert_at_random("---\n").to_s }
          end

          diff_document
        when "svn log --xml #{existing_trunk_url}",
             "svn log --xml #{existing_root_url}"
          xml_document = ""

          xml = Builder::XmlMarkup.new :target => xml_document
          xml.instruct!
          xml.log do
            options[:loc].to_a.sort.each do |rev|
              rev = rev[0]

              xml.logentry :revision => rev do
                xml.author "ruby"
                xml.date "2006-12-13T12:13:14.123456Z"
                xml.msg "Bugfixes."
              end
            end
          end

          xml_document
        when /svn ls -R --xml -r(\d+) (#{existing_trunk_url})/,
             /svn ls -R --xml -r(\d+) (#{existing_root_url})/
          url_used = $2
          revision = $1.to_i
          files_in_revision = options[:entries][revision].keys

          xml_document = ""

          xml = Builder::XmlMarkup.new :target => xml_document
          xml.instruct!
          xml.lists do
            xml.list :path => url_used do
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
        when /svn cat -r(\d+) #{existing_trunk_url}\/(.*)/,
             /svn cat -r(\d+) #{existing_root_url}\/(.*)/
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
  mock_svn

  specify "should raise SubversionError(No such repository) during creation" do
    lambda { SubversionRepository.new "file:///do/not/exist" }.should_raise SubversionError, "No such repository."
  end
end

context "Existing repository" do
  mock_svn

  specify "should be created without errors" do
    lambda { SubversionRepository.new "file:///existing/repository" }.should_not_raise SubversionError
  end
end

context "Empty repository" do
  mock_svn

  setup do
    @repo = SubversionRepository.new "file:///existing/repository"
  end

  specify "should have zero revisions" do
    @repo.revisions.nitems.should == 0
  end
end

context "Repository with one revision" do
  mock_svn :loc => { 1 => 5 }

  setup do
    @repo = SubversionRepository.new "file:///existing/repository"
  end

  specify "should have one revision" do
    @repo.revisions.nitems.should == 1
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
  mock_svn :loc => { 1 => 5, 2 => 13, 3 => 7 }

  setup do
    @repo = SubversionRepository.new "file:///existing/repository"
  end

  specify "should have three revisions" do
    @repo.revisions.nitems.should == 3
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
  mock_svn :loc => { 3 => 10, 4 => 46, 10 => 32, 12 => 32, 13 => 34 }

  setup do
    @repo = SubversionRepository.new "file:///existing/repository"
  end

  specify "should have five revisions" do
    @repo.revisions.nitems.should == 5
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
  mock_svn :loc => { 1 => 12, 2 => 36 },
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
  mock_svn :loc => { 1 => 4 },
           :entries => { 1 => { 'README' => 4.lines_of_code } }

  setup do
    @repo = SubversionRepository.new "file:///existing/repository/trunk"
  end

  specify "should report 4 LOC for revision(1)" do
    @repo.revision(1).loc.should == 4
  end
end

context "/trunk of repository with three empty revisions" do
  mock_svn :loc => { 1 => 0, 2 => 0, 5 => 0 }

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
  mock_svn :loc => { 1 => 0, 3 => 0, 5 => 0 },
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
