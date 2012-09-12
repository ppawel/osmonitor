require 'osmonitor/core'
require 'pg'

module OSMonitor
module RoadReport

class ReportManager
  include OSMonitorLogger

  attr_accessor :conn
  attr_accessor :road_manager

  def initialize(conn)
    self.conn = conn
    self.road_manager = create_road_manager(conn)
  end

  def create_road_manager(conn)
    RoadManager.new(conn)
  end

  def create_report_instance
    RoadReport.new
  end

  def create_status_instance(road)
    RoadStatus.new(road)
  end

  def generate_report(country, input, use_cache = false)
    report = create_report_instance
    report = OSMonitor::RoadReport::RoadReport.new
    report.report_request = ReportRequest.new
    report.report_request.report_type = 'ROAD_REPORT'

    @@log.debug "Got input (size = #{input.size})"

    input.each_with_index do |row, i|
      road_before = Time.now

      @@log.debug("BEGIN road #{country} / #{row['ref']} (#{i + 1} of #{input.size})")

      road = nil
      status = nil

      if use_cache
        status = status_from_cache(country, row['ref'])
        road = status.road if status
      end

      if !status or !road
        road = road_manager.load_road(country, row)

        @@log.debug(" Road loaded! Validating...")

        status = create_status_instance(road)
        status.validate

        @@log.debug(" Road validated! Caching...")

        cache_status(country, status)

        @@log.debug(" Cached!")
      end

      report.add_status(status)

      @@log.debug("END road #{country} / #{row['ref']} took #{Time.now - road_before}")
    end

    report
  end

  # Inserts given report status into the cache table.
  def cache_status(country, status)
    dump = PGconn.escape_bytea(Marshal.dump(status))
    @conn.query("UPDATE osmonitor_roads SET report_timestamp = NOW(), status = '#{dump}' WHERE id = #{status.road.row['id']}")
  end

  # Retrieves report status from the cache table.
  def status_from_cache(country, ref)
    result = @conn.query("SELECT status FROM osmonitor_roads WHERE country = '#{country}' AND ref = '#{ref}'")

    if result.ntuples == 1
      status = Marshal.restore(PGconn.unescape_bytea(result.getvalue(0, 0)))
      return status
    end
  end
end

end
end
