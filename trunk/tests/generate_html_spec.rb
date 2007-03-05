require 'stringio'

require 'svntl'
include SvnTimeline

context "Method generate_html" do
  mock_svn 'file:///existing/repository'

  setup do
    @repo = SubversionRepository.new 'file:///existing/repository'

    # Make generate_html public to allow direct testing.
    class << @repo ; public :generate_html ; end

    Dir.stub!(:mkdir)
    File.stub!(:exist?).and_return(false)
  end

  specify "should create file timeline/index.html" do
    File.stub!(:open).and_yield(StringIO.new)

    File.should_receive(:open).with('timeline/index.html', 'w').and_yield(StringIO.new)

    @repo.generate_html 'timeline'
  end

  specify "should read template from file templates\\index.rhtml on systems which has backslash as directory separator" do
    begin
      File.stub!(:open).and_yield(StringIO.new)
      File.metaclass.override!(:join).with do |*strings|
        strings.join("\\")
      end

      File.should_receive(:open).with('templates\\index.rhtml').and_yield(StringIO.new)

      @repo.generate_html 'timeline'
    ensure
      File.metaclass.restore! :join
    end
  end

  specify "should call File.open with default index.html template path to read the template" do
    File.stub!(:open).and_yield(StringIO.new)

    File.should_receive(:open).with('templates/index.rhtml').and_yield(StringIO.new)

    @repo.generate_html 'timeline'
  end

  specify "should rewrite default index.html template to timeline/index.html" do
    File.stub!(:open).and_yield(StringIO.new("Hello world!"))

    @output_file = mock 'output_file', :null_object => true
    File.should_receive(:open).with('timeline/index.html', 'w').and_yield(@output_file)

    @output_file.should_receive(:write).with("Hello world!")

    @repo.generate_html 'timeline'
  end

  specify "should call ERB.new with default template contents" do
    File.stub!(:open).and_yield(StringIO.new("Hello world!"))

    ERB.should_receive(:new).with("Hello world!").and_return(mock('null_erb_object', :null_object => true))

    @repo.generate_html 'whatever'
  end

  specify "should call template.result with a Binding" do
    File.stub!(:open).and_yield(StringIO.new)

    erb_object = mock('erb_object', :null_object => true)
    ERB.metaclass.override!(:new).and_return(erb_object)

    erb_object.should_receive(:result) do |b|
      b.should_be_a_kind_of Binding
    end

    @repo.generate_html 'whatever'
    ERB.metaclass.restore! :new
  end
end
