require 'osmonitor/core'
require 'erb'
require 'pg'

module OSMonitor

class ReportManager
  include OSMonitorLogger

  attr_accessor :conn
  attr_accessor :road_manager
  attr_accessor :report_template
  attr_accessor :erb_path

  def initialize(road_manager, erb_path = 'erb/')
    self.erb_path = erb_path
    self.conn = road_manager.conn
    self.road_manager = road_manager
    self.report_template = ERB.new(File.read("#{erb_path}road_report.erb"), nil, '<>')
  end

  def generate_road_report(country, refs, use_cache = false)
    report = RoadReport.new

    @@log.debug "Got #{refs.size} road(s) to process: #{refs}"

    refs.each_with_index do |ref, i|
      ref_prefix, ref_number = Road.parse_ref(ref)
      next if !ref_prefix or !ref_number

      road_before = Time.now

      @@log.debug("BEGIN road #{country} / #{ref_prefix + ref_number} (#{i + 1} of #{refs.size})")

      road = nil
      status = nil

      if use_cache
        status = status_from_cache(country, ref)
        road = status.road if status
      end

      if !status or !road
        road = road_manager.load_road(country, ref_prefix, ref_number)

        @@log.debug(" Road loaded! Validating...")

        status = RoadStatus.new(road)
        status.validate

        @@log.debug(" Road validated! Caching...")

        cache_status(country, status)

        @@log.debug(" Cached!")
      end

      report.add_status(status)

      @@log.debug("END road #{country} / #{road.ref_prefix + road.ref_number} took #{Time.now - road_before} " +
        "(comps = #{status.road.comps.map {|c| c.graph.num_vertices}.inspect})")
    end

    @@log.debug "Done processing roads, rendering the report..."

    report_text = @report_template.result(binding()).force_encoding('UTF-8')

    @@log.debug "Done!"

    return report, report_text
  end

  # Inserts given report status into the cache table.
  def cache_status(country, status)
    dump = PGconn.escape_bytea(Marshal.dump(status))
    @conn.query("DELETE FROM report_statuses WHERE country = '#{country}' AND road_ref = '#{status.road.ref_prefix}#{status.road.ref_number}'")
    @conn.query("INSERT INTO report_statuses (road_ref, country, cached_date, status) VALUES
      ('#{status.road.ref_prefix}#{status.road.ref_number}', '#{country}', NOW(), '#{dump}')")
  end

  # Retrieves report status from the cache table.
  def status_from_cache(country, ref)
    result = @conn.query("SELECT status FROM report_statuses WHERE country = '#{country}' AND road_ref = '#{ref}'")

    if result.ntuples == 1
      status = Marshal.restore(PGconn.unescape_bytea(result.getvalue(0, 0)))
      return status
    end
  end

  def render(file, status = nil, issue = nil)
    return ERB.new(File.read("#{@erb_path}#{file}"), nil, '<>').result(binding)
  end
end

end
