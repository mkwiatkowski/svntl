require 'rubygems'
require_gem 'builder'

require 'svntl'
include SvnTimeline

# Imitate running "svn info --xml".
module Spec::Runner::ContextEval::ModuleMethods
  def mock_svn options={}
    setup do
      SubversionRepository.override!(:execute_command).with do |command|
        if command == 'svn info --xml file:///existing/repository'
          options = { :revisions => 0 }.merge!(options)
          revisions = options.values_at(:revisions)

          xml_document = ""

          xml = Builder::XmlMarkup.new :target => xml_document
          xml.instruct!
          xml.info do
            xml.entry :kind => "dir", :path => "repository", :revision => revisions do
              xml.url "file:///existing/repository"
              xml.repository do
                xml.root "file:///existing/repository"
                xml.uuid ""
              end
              xml.commit :revision => revisions do
                xml.author "ruby"
                xml.date "2006-12-13T12:13:14.123456Z"
              end
            end
          end

          xml_document
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

  specify "should raise SubversionError during creation" do
    lambda { SubversionRepository.new "file:///do/not/exist" }.should_raise SubversionError
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
    @repo.revisions.should == 0
  end
end

context "Repository with one revision" do
  mock_svn :revisions => 1

  setup do
    @repo = SubversionRepository.new "file:///existing/repository"
  end

  specify "should have one revision" do
    @repo.revisions.should == 1
  end
end
