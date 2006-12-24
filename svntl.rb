require 'rexml/document'

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

  class SubversionError < StandardError
  end

  class SubversionRepository
    attr_reader :revisions

    def initialize url
      @url = url
      get_info
    end

    private
    def get_info
      begin
        doc = REXML::Document.new execute_command("svn info --xml #{@url}")
        @revisions = Integer doc.elements["/info/entry"].attributes["revision"]
      rescue IOError
        raise SubversionError
      end
    end
  end
end
