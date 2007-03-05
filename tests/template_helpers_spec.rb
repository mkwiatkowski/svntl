require 'svntl'
include SvnTimeline::TemplateHelpers

context "Method vertical_text" do
  specify "should return empty string on empty string" do
    vertical_text("").should == ""
  end

  specify "should return no <br />s for one character" do
    vertical_text("a").should == "a"
  end

  specify "should return single <br /> for two characters" do
    vertical_text("ab").should == "a<br />b"
  end

  specify "should return five <br />s for string of six characters" do
    vertical_text("abcdef").scan(%r{<br />}).length.should == 5
  end
end
