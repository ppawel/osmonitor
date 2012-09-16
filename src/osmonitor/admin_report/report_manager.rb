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

  def generate_report(country, input, use_cache = false)
    report = AdminReport.new
    report.report_request = ReportRequest.new
    report.report_request.report_type = 'ADMIN_REPORT'

    @@log.debug "Got input (size = #{input.size})"

    input.each_with_index do |row, i|
      road_before = Time.now

      @@log.debug("BEGIN boundary #{country} / admin_level = #{row['admin_level']} / name = #{row['name']} (#{i + 1} of #{input.size})")

      boundary = admin_manager.load_boundary(country, row, input)

      @@log.debug(" Entity loaded! Validating...")

      status = BoundaryStatus.new(boundary)
      status.validate

      report.add_status(status)

      @@log.debug("END boundary #{country} / admin_level = #{row['admin_level']} / name = #{row['name']} (#{i + 1} of #{input.size}) took #{Time.now - road_before}")
    end

    report
  end
end

end
end
