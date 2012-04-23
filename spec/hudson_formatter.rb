require "time"
require "rspec/core/formatters/progress_formatter"

class HudsonFormatter < RSpec::Core::Formatters::ProgressFormatter
  def initialize(output)
    super(output)
    system "rm -rf junit/rspec ; mkdir -p junit/rspec"
  end

  def example_passed(example)
    super(example)
    Group.current.push(example)
  end

  def example_pending(example)
    super(example)
    Group.current.push(example)
  end

  def example_failed(example)
    super(example)
    Group.current.push(example)
  end

  def read_failure(t)
    exception = t.metadata[:execution_result][:exception_encountered] || t.metadata[:execution_result][:exception]
    message = ""
    unless (exception.nil?)
      message  = exception.message
      message += "\n"
      message += format_backtrace(exception.backtrace, t).join("\n")
    end
    return(message)
  end

  def self.sanitize name
    return '' if name.nil?
    result = name.dup
    result.gsub!(/<=/, 'less than or equal to')
    result.gsub!(/>=/, 'greater than or equal to')
    result.gsub!(/</, 'less than')
    result.gsub!(/</, 'greater than')
    result.gsub!(/%/, 'percent')
    result.gsub!(/&/, 'and')
    result.gsub!(/\|\|/, 'or')
    result.gsub!(/\"/, '\'')
    result
  end

  def self.cdata(data)
    return '' if data.nil?
    result = data.dup
    result.gsub!('<![CDATA[', '(CDATA)[')
    result.gsub!(']]>', ']')
    "<![CDATA[ #{result} ]]>"
  end

  class Group
    class << self
      attr_accessor :current
    end

    attr_accessor :me, :parent, :results, :file, :start

    def initialize me
      self.me = me
      self.parent = Group.current
      Group.current = self
      self.results = []

      self.start = Time.now
    end

    def push example
      self.results.push(example)
    end

    def failures_count
      results.count{ |e| e.metadata[:execution_result][:status] == 'failed' }
    end

    def skipped_count
      results.count{ |e| e.metadata[:execution_result][:status] == 'pending' }
    end

    def successes_count
      results.count{ |e| e.metadata[:execution_result][:status] == 'passed' }
    end

    def tests_count
      successes_count + skipped_count + failures_count
    end

    def has_results?
      !results.empty?
    end

    def end
      Group.current = parent
    end

    def path
      me.metadata[:example_group][:file_path]
    end

    def spec_path
      sub_path = path.include?('spec/') ? path[path.index(/spec\//)+5..-1] : path
      sub_path = sub_path || ''
      sub_path.gsub!(/[\.\/]/, '-')
    end

    def line_number
      me.metadata[:example_group][:line_number]
    end

    def describes
      klass = me.metadata[:example_group][:describes]
      klass = klass.respond_to?(:name) ? klass.name : klass
      klass.nil? ? 'NULL' : klass.gsub(/:/, '-')
    end

    def filename
      "junit/rspec/SPEC-#{describes}-#{spec_path}-#{line_number}.xml"
    end

    def description
      me.metadata[:example_group][:description]
    end

    def full_description
      me.metadata[:example_group][:full_description]
    end

    def parent?
      description == full_description
    end

    def duration
      Time.now-start
    end

    def put_header
      self.file = File.new(filename, 'w')
      file.puts("<?xml version=\"1.0\" encoding=\"utf-8\" ?>")
      file.puts("<testsuite errors=\"0\" name=\"#{HudsonFormatter.sanitize(full_description)}\" failures=\"#{failures_count}\" skipped=\"#{skipped_count}\" tests=\"#{tests_count}\" time=\"#{duration}\" timestamp=\"#{Time.now.iso8601}\">")
    end

    def put_footer
      file.puts("</testsuite>")
      file.close
    end
  end

  def example_group_started group
    Group.new(group)
  end

  def example_group_finished group
    if Group.current.has_results?
      Group.current.put_header
      Group.current.results.each do |result|
        md = result.metadata
        runtime = md[:execution_result][:run_time]
        description = md[:description]
        Group.current.file.puts("<testcase name=\"#{HudsonFormatter.sanitize(description)}\" time=\"#{runtime}\">")
        if md[:execution_result][:status] == 'pending'
          Group.current.file.puts("  <skipped />")
        elsif md[:execution_result][:status] == 'failed'
          Group.current.file.puts("  <failure message=\"failure\" type=\"falure\">")
          Group.current.file.puts("    #{HudsonFormatter.cdata(read_failure(result))}")
          Group.current.file.puts("  </failure>")
        end
        Group.current.file.puts("</testcase>")
      end
      Group.current.put_footer
    end
    Group.current.end
  end

  def dump_summary(duration, example_count, failure_count, pending_count)
    super(duration, example_count, failure_count, pending_count)
  end
end
