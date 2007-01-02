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

######################################################################
# Data retrieval part.
module Enumerable
  def sort_by! symbol
    sort! { |a, b| a.send(symbol) <=> b.send(symbol) }
  end
end

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
    def initialize
      # Each repository have revision 0 with zero LOC.
      self << Revision.new(0)
    end

    def number
      # Revision 0 is virtual and should not be counted.
      size - 1
    end

    # Bind revisions with the same date together.
    def by_day
      inject(Hash.new {[]}) do |hash, rev|
        hash[rev.date] <<= rev
        hash
      end
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

      doc.get_elements("/lists/list/entry[@kind='file']/name").inject(0) do |loc, path|
        loc += execute_command("svn cat -r#{number} #{@url}/#{path.text}").to_a.size
      end
    end

    def init_revisions
      begin
        doc = REXML::Document.new execute_command("svn log --xml #{@url}")

        doc.each_element("/log/logentry") do |logentry|
          @revisions << Revision.new(logentry.attributes["revision"].to_i,
                                     :date => Date.strptime(logentry.text("date")))
        end

        @revisions.sort_by! :number

        @revisions.each_cons(2) do |r1, r2|
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
  def keys_and_values
    return [[], []] if empty?
    transpose
  end
end

class Hash
  def self.from_keys_and_values keys, values
    Hash[*keys.zip(values).flatten]
  end
end

class Integer
  def labels_from data
    jump = (data.size / self.to_f).ceil

    indexes = (0...data.size).select { |i| i % jump == 0 }
    Hash.from_keys_and_values(indexes, data.values_at(*indexes))
  end
end

module SvnTimeline
  class SubversionRepository
    def chart_loc max_labels, options={}
      revisions = trim_zeroes(@revisions)

      if options[:small]
        @chart = Gruff::Line.new 200
      else
        @chart = Gruff::Line.new
      end

      labels, data = yield(revisions).sort.keys_and_values

      @chart.data "LOC", data
      @chart.labels = max_labels.labels_from labels

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
      chart_loc(20, options) do |revisions|
        revisions.map { |rev| [rev.number.to_s, rev.loc] }
      end
    end

    def chart_loc_per_day options={}
      chart_loc(10, options) do |revisions|
        revisions.by_day.map { |date, revs| [date.to_s, revs.last.loc] }
      end
    end

    private
    def trim_zeroes revisions
      while not revisions.empty? and revisions[0].loc == 0
        revisions = revisions.slice(1, revisions.size - 1)
      end
      revisions
    end
  end
end