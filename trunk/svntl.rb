require 'date'
require 'erb'
require 'enumerator'
require 'rexml/document'

# Ignore non-existent rubygems.
begin
  require 'rubygems'
rescue LoadError
  nil
end

# Require a gem and provide usefull error message if require wasn't successful.
def save_require module_name, reason, rubyforge_id
  require module_name
rescue LoadError
  $stderr.puts "You don't seem to have #{module_name.capitalize} library installed. It is needed for #{reason}.",
               "To install with Ruby Gems:",
               "  sudo gem install #{module_name}",
               "If you don't have Gems, install manually from http://rubyforge.org/frs/?group_id=#{rubyforge_id} ."
  exit 1
end

save_require 'gruff', 'chart generation', 1044
save_require 'open4', 'running `svn` command', 1024

######################################################################
# Data retrieval part.
module Enumerable
  def sort_by! method
    sort! { |a, b| a.send(method) <=> b.send(method) }
  end
end

module SvnTimeline
  # Execute given command, returning its output on success.
  # On error raise IOError.
  def execute_command command
    output = ''
    Open4::popen4(command) do |pid, stdin, stdout, stderr|
      output = stdout.read
    end

    raise IOError unless $?.success?

    return output
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
    def initialize options={}
      # Each repository have revision 0 with zero LOC.
      self << Revision.new(0) unless options[:without_revision_zero]
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

    # Return new ListOfRevisions with trailing empty revisions removed.
    def without_trailing_empty
      inject(ListOfRevisions.new(:without_revision_zero => true)) do |revisions, rev|
        revisions << rev if not revisions.empty? or rev.loc > 0
        revisions
      end
    end
  end

  class SubversionError < StandardError
  end

  class SubversionRepository
    #
    # Name of the project held in this repository.
    # This attribute defines a title of HTML documents that will be generated.
    #
    attr_reader :project_name

    # Full list of revisions in this repository (including virtual revision 0).
    attr_reader :revisions

    def initialize url, options={}
      @url = url
      @project_name = (options[:project_name] or url)

      @revisions = ListOfRevisions.new

      init_revisions
    end

    # Get Revision object of given number.
    def revision number
      @revisions.find { |rev| rev.number == number } or raise SubversionError, "No such revision."
    end

    private
    def get_loc_of_revision number
      # Calling recursive ls to instantly get full list of files.
      doc = REXML::Document.new execute_command("svn ls -R --xml -r#{number} #{@url}")

      # If there is only one entry it may be the case when URL points to
      # the file itself. SVN gives us no hints here, so let's try both options.
      if doc.get_elements("/lists/list/entry").length == 1
        begin
          execute_command("svn cat -r#{number} #{@url}").to_a.size
        rescue IOError
          name = doc.get_elements("/lists/list/entry[@kind='file']/name").first.text
          execute_command("svn cat -r#{number} #{@url}/#{name}").to_a.size
        end
      else
        doc.get_elements("/lists/list/entry[@kind='file']/name").inject(0) do |loc, path|
          loc += execute_command("svn cat -r#{number} #{@url}/#{path.text}").to_a.size
        end
      end
    end

    def init_revisions
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

######################################################################
# Generation of graphical charts.
class Array
  def keys_and_values
    return [[], []] if empty?
    transpose
  end

  def map_with method
    map { |element| element.send(method) }
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
    Chart = Struct.new(:method, :title, :color)
    class Chart
      def filename ; "#{method}.png" ; end
      def small_filename ; "#{method}_small.png" ; end
    end

    AvailableCharts = [
        Chart.new('chart_loc_per_commit', 'Lines of Code per commit', 'blue'),
        Chart.new('chart_loc_per_day',    'Lines of Code per day',    'red'),
    ]

    def chart_loc_per_commit options={}
      chart_loc(20, options) do |revisions|
        revisions.map { |rev| [rev.number, rev.loc] }
      end
    end

    def chart_loc_per_day options={}
      chart_loc(8, options) do |revisions|
        rev_by_day = revisions.by_day

        unless revisions.empty?
          last_touched_rev = revisions.first

          # Insert all intermediate dates.
          revisions.first.date.step(revisions.last.date, 1) do |date|
            if rev_by_day.include? date
              last_touched_rev = rev_by_day[date].last
            else
              rev_by_day[date] <<= Revision.new(-1, :loc => last_touched_rev.loc)
            end
          end
        end
        
        rev_by_day.map { |date, revs| [date, revs.last.loc] }
      end
    end

    private
    def chart_loc max_labels, options={}
      revisions = @revisions.without_trailing_empty

      if options[:small]
        @chart = Gruff::Line.new 120
      else
        @chart = Gruff::Line.new 500
      end

      @chart.theme = {
        :colors => [ (options[:color] or 'blue') ],
        :marker_color => 'black',
        :font_color => 'black',
        :background_colors => ['white', 'white']
      }

      labels, data = yield(revisions).sort.keys_and_values

      @chart.data "LOC", data
      @chart.labels = max_labels.labels_from labels.map_with(:to_s)

      if options[:title]
        @chart.title = options[:title]
      else
        @chart.hide_title = true
      end

      @chart.hide_dots = true
      @chart.hide_legend = true
      @chart.marker_font_size = 15

      if options[:small]
        @chart.hide_line_markers = true
        @chart.title_font_size = 50
      end

      @chart.write((options[:file] or 'loc.png'))
    end

    # Generate charts and save them to _directory_.
    def generate_charts directory
      AvailableCharts.each do |chart|
        send chart.method, :file => File.join(directory, chart.filename),
                           :color => chart.color
        send chart.method, :file => File.join(directory, chart.small_filename),
                           :color => chart.color,
                           :title => chart.title,
                           :small => true
      end
    end
  end
end

######################################################################
# Generation of HTML pages.
module SvnTimeline
  def read_file path
    File.open(path) { |file| file.read }
  end

  class SubversionRepository
    private
    # Generate HTML files and save them to _directory_.
    def generate_html directory
      template = ERB.new(read_file('templates/index.rhtml'))

      File.open(File.join(directory, 'index.html'), 'w') do |file|
        file.write(template.result(binding))
      end
    end
  end
end

######################################################################
# Generation of full statistics data (HTML + images).
module SvnTimeline
  class SubversionRepository
    #
    # Generate all statistics files and save them to the same
    # directory.
    #
    # Default directory is 'timeline', but you can override this
    # by passing _directory_ argument.
    #
    def generate_statistics directory='timeline'
      Dir.mkdir(directory) unless File.exist?(directory)

      generate_charts directory
      generate_html directory
    end
  end
end
