require 'rexml/document'

class Array
  def each_cons length
    each_index do |i|
      if i + length > size
        break
      end

      yield slice(i, length)
    end
  end
end

class REXML::Document
  def inject_elements xpath, initial=nil
    first = true

    each_element(xpath) do |element|
      if first and initial == nil
        initial = element
        first = false
      else
        initial = yield initial, element
      end
    end

    initial
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
    attr_reader :number
    attr_accessor :loc

    def initialize number
      @number = number
      @loc = 0
    end
  end

  class SubversionError < StandardError
  end

  class SubversionRepository
    attr_reader :last_revision, :revisions

    def initialize url
      @url = url
      @revisions = []

      # Each repository have revision 0 with zero LOC.
      @revisions << Revision.new(0)

      # But we should remember that revision 0 is virtual
      # and should not be counted.
      class << @revisions
        alias_method :orig_nitems, :nitems

        def nitems
          orig_nitems - 1
        end
      end

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
          @revisions << Revision.new(logentry.attributes["revision"].to_i)
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
