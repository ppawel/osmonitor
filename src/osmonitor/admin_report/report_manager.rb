require 'osmonitor'

module OSMonitor
module AdminReport

class ReportManager
  include OSMonitorLogger

  attr_accessor :conn
  attr_accessor :admin_manager

  def initialize(conn)
    self.conn = conn
    self.admin_manager = AdminManager.new(conn)
  end

  def generate_report(country, report_request, all_input, use_cache = false)
    report = AdminReport.new
    report.report_request = report_request

    filtered_input = filter_input(report_request, all_input)

    @@log.debug "Got input (size = #{filtered_input.size}), report_request = #{report_request.inspect}"

    filtered_input.each_with_index do |row, i|
      road_before = Time.now

      @@log.debug("BEGIN boundary #{country} / admin_level = #{row['admin_level']} / name = #{row['name']} (#{i + 1} of #{filtered_input.size})")

      boundary = admin_manager.load_boundary(country, row, all_input)

      @@log.debug(" Entity loaded! Validating...")

      status = BoundaryStatus.new(boundary)
      status.validate

      report.add_status(status)

      @@log.debug("END boundary #{country} / admin_level = #{row['admin_level']} / name = #{row['name']} (#{i + 1} of #{filtered_input.size}) took #{Time.now - road_before}")
    end

    report
  end

  def filter_input(report_request, all_input)
    result = all_input
    result = all_input.select {|input| eval(report_request.filter)} if report_request.filter
    result
  end
end

end
end
