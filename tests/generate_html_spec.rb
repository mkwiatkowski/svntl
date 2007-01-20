require 'stringio'

require 'svntl'
include SvnTimeline

context "Method generate_html" do
  mock_svn 'file:///existing/repository'

  setup do
    @repo = SubversionRepository.new 'file:///existing/repository'

    Dir.stub!(:mkdir)
  end

  specify "should create directory timeline/ if repository exists" do
    File.stub!(:exist?).and_return(false)
    File.stub!(:open).and_yield(StringIO.new)

    Dir.should_receive(:mkdir).with('timeline')

    @repo.generate_html 
  end

  specify "should not try to create existing timeline/ directory" do
    File.stub!(:exist?).and_return(true)
    File.stub!(:open).and_yield(StringIO.new)

    Dir.should_not_receive(:mkdir)

    @repo.generate_html 
  end

  specify "should create file timeline/index.html if repository exists" do
    File.stub!(:exist?).and_return(false)
    File.stub!(:open).and_yield(StringIO.new)

    File.should_receive(:open).with('timeline/index.html', 'w').and_yield(StringIO.new)

    @repo.generate_html 
  end

  specify "should call File.open with default index.html template path to read the template" do
    File.stub!(:exist?).and_return(false)
    File.stub!(:open).and_yield(StringIO.new)

    File.should_receive(:open).with('templates/index.rhtml').and_yield(StringIO.new)

    @repo.generate_html 
  end

  specify "should rewrite default index.html template to timeline/index.html" do
    File.stub!(:exist?).and_return(false)
    File.stub!(:open).and_yield(StringIO.new("Hello world!"))

    @output_file = mock 'output_file', :null_object => true
    File.should_receive(:open).with('timeline/index.html', 'w').and_yield(@output_file)

    @output_file.should_receive(:write).with("Hello world!")

    @repo.generate_html 
  end

  specify "should call ERB.new with default template contents" do
    File.stub!(:exist?).and_return(false)
    File.stub!(:open).and_yield(StringIO.new("Hello world!"))

    ERB.should_receive(:new).with("Hello world!").and_return(mock('null_erb_object', :null_object => true))

    @repo.generate_html 
  end

  specify "should call template.result with a Binding" do
    File.stub!(:exist?).and_return(false)
    File.stub!(:open).and_yield(StringIO.new)

    erb_object = mock('erb_object', :null_object => true)
    ERB.metaclass.override!(:new).and_return(erb_object)

    erb_object.should_receive(:result) do |b|
      b.should_be_a_kind_of Binding
    end

    @repo.generate_html 
    ERB.metaclass.restore! :new
  end
end
