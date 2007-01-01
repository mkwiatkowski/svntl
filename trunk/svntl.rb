require 'date'
require 'enumerator'
require 'rexml/document'

require 'rubygems'
begin
  require 'gruff'
rescue LoadError
  $stderr.puts "You don't seem to have Gruff library installed. It is needed for chart generation.",
               "To install with Ruby Gems:",
               "  sudo gem install gruff",
               "If you don't have Gems, install manually from http://rubyforge.org/frs/?group_id=1044 ."
end

class REXML::Document
  def inject_elements xpath, initial=nil, &block
    if initial == nil
      get_elements(xpath).inject { |*args| block.call(*args) }
    else
      get_elements(xpath).inject(initial) { |*args| block.call(*args) }
    end
  end
end

######################################################################
# Data retrieval part.
module SvnTimeline

  # Execute given command, returning its output on success.
  # On error raise IOError.
  def execute_command command
    stdout = `#{command}`

    if not $?.success?
      raise IOError
    end

    return stdout
  end

  class Revision
    attr_reader :date, :number
    attr_accessor :loc

    def initialize number, options={}
      @number = number
      @loc = (options[:loc] or 0)
      @date = (options[:date] or nil)
    end
  end

  class ListOfRevisions < Array
    alias_method :orig_nitems, :nitems

    def initialize
      # Each repository have revision 0 with zero LOC.
      self << Revision.new(0)
    end

    # Revision 0 is virtual and should not be counted.
    def nitems
      orig_nitems - 1
    end

    # Bind revisions with the same date together.
    def by_day
      hash = Hash.new { [] }
      each { |rev| hash[rev.date] <<= rev }
      hash
    end
  end

  class SubversionError < StandardError
  end

  class SubversionRepository
    attr_reader :last_revision, :revisions

    def initialize url
      @url = url
      @revisions = ListOfRevisions.new

      init_revisions
    end

    def revision number
      @revisions.find { |rev| rev.number == number } or raise SubversionError, "No such revision."
    end

    private
    def get_loc_of_revision number
      # Calling recursive ls to instantly get full list of files.
      doc = REXML::Document.new execute_command("svn ls -R --xml -r#{number} #{@url}")

      doc.inject_elements("/lists/list/entry[@kind='file']/name", 0) do |memo, path|
        memo += execute_command("svn cat -r#{number} #{@url}/#{path.text}").to_a.size
      end
    end

    def each_revision_pair
      @revisions.each_cons(2) { |pair| yield(*pair) }
    end

    def init_revisions
      begin
        doc = REXML::Document.new execute_command("svn log --xml #{@url}")

        doc.each_element("/log/logentry") do |logentry|
          @revisions << Revision.new(logentry.attributes["revision"].to_i,
                                     :date => Date.strptime(logentry.text("date")))
        end

        @revisions.sort! { |r1, r2| r1.number <=> r2.number }

        each_revision_pair do |r1, r2|
          begin
            doc = execute_command("svn diff -r#{r1.number}:#{r2.number} --diff-cmd \"diff\" -x \"--normal\" #{@url}")
            removed = doc.grep(/^</).size
            added = doc.grep(/^>/).size
            r2.loc = r1.loc + added - removed
          rescue IOError
            # Protect from situation when checking for file which didn't exist in rev. 0.
            raise unless r1.number == 0
            r2.loc = get_loc_of_revision r2.number
          end
        end
      rescue IOError
        raise SubversionError, "No such repository."
      end
    end
  end
end

######################################################################
# Generation of graphical charts.
class Array
  def each_nth_with_index jump
    each_with_index do |element, index|
      if index % jump == 0
        yield element, index
      end
    end
  end

  def keys
    map { |key, value| key }
  end

  def values
    map { |key, value| value }
  end
end

class Hash
  def hmap
    each_pair do |key, value|
      store key, yield(value)
    end
  end
end

module SvnTimeline
  class SubversionRepository
    def chart_loc options={}
      revisions = trim_zeroes(@revisions)

      if options[:small]
        @chart = Gruff::Line.new 200
      else
        @chart = Gruff::Line.new
      end

      # Caller should set chart.data and chart.labels.
      yield @chart, revisions

      @chart.title = (options[:title] or @url)
      @chart.hide_dots = true
      @chart.hide_legend = true
      @chart.marker_font_size = 10

      if options[:small]
        @chart.hide_line_markers = true
        @chart.title_font_size = 50
      end

      @chart.write((options[:file] or 'loc.png'))
    end

    def chart_loc_per_commit options={}
      chart_loc options do |chart, revisions|
        chart.data "LOC", revisions.map { |r| r.loc }
        chart.labels = labels_for(revisions) { |r| r.number.to_s }
      end
    end

    def chart_loc_per_day options={}
      chart_loc options do |chart, revisions|
        revisions = revisions.by_day.hmap { |r| r.last.loc }
        chart.data "LOC", revisions.sort.values
        chart.labels = labels_for(revisions.sort.keys, 10) { |d| d.to_s }
      end
    end

    private
    def trim_zeroes revisions
      while not revisions.empty? and revisions[0].loc == 0
        revisions = revisions.slice(1, revisions.size - 1)
      end
      revisions
    end

    def labels_for revisions, maximum=20
      # To ensure that there will be enough place for labels
      #   use at most @maximum of them.
      jump = (revisions.size / maximum.to_f).ceil

      labels = {}
      revisions.each_nth_with_index(jump) do |rev, idx|
        labels[idx] = yield rev
      end
      labels
    end
  end
end
