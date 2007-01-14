require 'stringio'

require 'svntl'
include SvnTimeline

context "generate_html method for non-existing repository" do
  include ContextHelper

  setup do
    SubversionRepository.stub!(:new).and_raise(SubversionError.new("No such repository."))

    File.stub!(:exist?).and_return(false)
    Dir.stub!(:mkdir)
  end

  specify "should not create any directory" do
    Dir.should_not_receive(:mkdir)
    without_exception(SubversionError) { generate_html 'file:///do/not/exist' }
  end

  specify "should not create any HTML files" do
    File.should_not_receive(:open)
    without_exception(SubversionError) { generate_html 'file:///do/not/exist' }
  end

  specify "should raise SubversionError(No such repository) during call" do
    lambda { generate_html 'file:///do/not/exist' }.should_raise SubversionError, "No such repository."
  end
end

context "generate_html method for existing repository" do
  setup do
    @repository_object = mock 'subversion_repository_object', :null_object => true
    @repository_object.stub!(:get_binding).and_return(binding)
    SubversionRepository.stub!(:new).and_return(@repository_object)

    Dir.stub!(:mkdir)
  end

  specify "should create directory timeline/ if repository exists" do
    File.stub!(:exist?).and_return(false)
    File.stub!(:open).and_yield(StringIO.new)

    Dir.should_receive(:mkdir).with('timeline')

    generate_html 'file:///existing/repository'
  end

  specify "should not try to create existing timeline/ directory" do
    File.stub!(:exist?).and_return(true)
    File.stub!(:open).and_yield(StringIO.new)

    Dir.should_not_receive(:mkdir)

    generate_html 'file:///existing/repository'
  end

  specify "should create file timeline/index.html if repository exists" do
    File.stub!(:exist?).and_return(false)
    File.stub!(:open).and_yield(StringIO.new)
    File.should_receive(:open).with('timeline/index.html', 'w')

    generate_html 'file:///existing/repository'
  end

  specify "should call File.open with default index.html template path to read the template" do
    File.stub!(:exist?).and_return(false)
    File.stub!(:open).and_yield(StringIO.new)
    File.should_receive(:open).with('templates/index.rhtml').and_yield(StringIO.new)

    generate_html 'file:///existing/repository'
  end

  specify "should call ERB.new with default template contents" do
    File.stub!(:exist?).and_return(false)
    File.stub!(:open).and_yield(StringIO.new("Hello world!"))

    ERB.should_receive(:new).with("Hello world!").and_return(mock('null_erb_object', :null_object => true))

    generate_html 'file:///existing/repository'
  end

  specify "should call template.result with a Binding" do
    File.stub!(:exist?).and_return(false)
    File.stub!(:open).and_yield(StringIO.new)

    @erb_object = mock 'erb_object', :null_object => true
    ERB.stub!(:new).and_return(@erb_object)

    @erb_object.should_receive(:result) do |binding|
      binding.should_be_a_kind_of Binding
    end

    generate_html 'file:///existing/repository'
  end

  specify "should call repository get_binding method" do
    File.stub!(:exist?).and_return(false)
    File.stub!(:open).and_yield(StringIO.new)

    @repository_object.should_receive(:get_binding).and_return(binding)

    generate_html 'file:///existing/repository'
  end

  specify "should rewrite default index.html template to timeline/index.html" do
    File.stub!(:exist?).and_return(false)
    File.stub!(:open).and_yield(StringIO.new("Hello world!"))

    @output_file = mock 'output_file', :null_object => true
    File.should_receive(:open).with('timeline/index.html', 'w').and_yield(@output_file)

    @output_file.should_receive(:write).with("Hello world!")

    generate_html 'file:///existing/repository'
  end
end
