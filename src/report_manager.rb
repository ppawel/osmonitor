require 'core'
require 'erb'

module OSMonitor

class ReportManager
  include OSMonitorLogger

  attr_accessor :road_manager
  attr_accessor :report_template
  attr_accessor :erb_path

  def initialize(road_manager, erb_path = 'erb/')
    self.erb_path = erb_path
    self.road_manager = road_manager
    self.report_template = ERB.new(File.read("#{erb_path}road_report.erb"), nil, '<>')
  end

  def generate_road_report(country, refs)
    report = RoadReport.new

    @@log.debug "Got #{refs.size} road(s) to process"

    refs.each_with_index do |ref, i|
      ref_prefix, ref_number = Road.parse_ref(ref)
      road_before = Time.now

      @@log.debug("BEGIN road #{ref_prefix + ref_number} (#{i + 1} of #{refs.size})")

      road = road_manager.load_road(country, ref_prefix, ref_number)

      @@log.debug(" Road loaded! Validating...")

      status = RoadStatus.new(road)
      status.validate

      @@log.debug(" Road validated!")

      report.add_status(status)

      @@log.debug("END road #{road.ref_prefix + road.ref_number} took #{Time.now - road_before} " +
        "(comps = #{status.road.comps.map {|c| c.graph.num_vertices}.inspect})")
    end

    @@log.debug "Done processing roads, rendering the report..."

    report_text = @report_template.result(binding())

    @@log.debug "Done!"

    return report, report_text
  end

  def render(file, status = nil, issue = nil)
    return ERB.new(File.read("#{@erb_path}#{file}"), nil, '<>').result(binding)
  end
end

end
