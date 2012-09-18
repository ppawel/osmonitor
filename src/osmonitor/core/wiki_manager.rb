require 'config'
require 'erb'
require 'media_wiki'

module OSMonitor

# Responsible for:
# * interaction with a MediaWiki instance (can fetch/update pages)
# * processing (parsing, replacing) OSMonitor segments in a wiki page
# * rendering reports with wiki-compatible syntax
class WikiManager
  attr_accessor :admin_report_manager
  attr_accessor :cycleway_report_manager
  attr_accessor :road_report_manager
  attr_accessor :input_manager
  attr_accessor :gateway

  def initialize(admin_report_manager, cycleway_report_manager, road_report_manager)
    self.admin_report_manager = admin_report_manager
    self.cycleway_report_manager = cycleway_report_manager
    self.road_report_manager = road_report_manager
    self.input_manager = InputManager.new
    self.gateway = MediaWiki::Gateway.new('https://wiki.openstreetmap.org/w/api.php')
  end

  def get_erb_path(report_type)
    $osmonitor_home_dir + "/erb"
  end

  def login(user, password)
    @gateway.login(user, password)
  end

  def render_reports_on_page(page)
    overall_report = OSMonitor::RoadReport::RoadReport.new
    overall_report.report_request = ReportRequest.new
    overall_report.report_request.report_type = 'ROAD_REPORT'

    page.get_segments('ADMIN_REPORT').each {|segment| render_report(@admin_report_manager, page, segment, overall_report)}
    page.get_segments('CYCLEWAY_REPORT').each {|segment| render_report(@cycleway_report_manager, page, segment, overall_report)}
    page.get_segments('ROAD_REPORT').each {|segment| render_report(@road_report_manager, page, segment, overall_report)}
    page.get_segments('ROAD_STATS').each {|segment| replace_segment(page, segment, render_stats(overall_report))}
  end

  def render_report(manager, page, segment, overall_report)
    report_request = segment.to_report_request
    country = segment.params['country']
    report_text = nil

    input = @input_manager.load(report_request)
    report = manager.generate_report(country, input)
    report.report_request = report_request
    overall_report.add(report)

    report_text = render_erb("wiki_#{report_request.report_type.downcase}.erb", country, report)
    replace_segment(page, segment, report_text)
  end

  def render_erb(file, country, report = nil, status = nil, issue = nil)
    return ERB.new(File.read("#{get_erb_path(report.report_request.report_type)}/#{file}"), nil, '<>').result(binding)
  end

  def render_stats(report)
     render_erb('wiki_road_report_stats.erb', nil, report)
  end

  def get_osmonitor_page(input_page)
    page = OSMonitorWikiPage.new
    page.text = @gateway.get(input_page)
    old_page_text = page.text.dup

    old_page_text.scan(/((<\!\-\- OSMonitor ([^\s]+)(.*?)\-\->).*?(<\!\-\- OSMonitor \/\3 \-\->))/mi) do |match|
      segment = OSMonitorWikiPageSegment.new
      segment.all = match[0]
      segment.beginning = match[1]
      segment.ending = match[4]
      segment.type = match[2]
      segment.params = parse_params(match[3])

      page.segments << segment
    end

    page
  end

  def replace_segment(page, segment, new_text)
    page.text[segment.all] = "#{segment.beginning}#{new_text}#{segment.ending}"
  end

  def save_page(page, page_name)
    @gateway.create(page_name, page.text, :overwrite => true, :summary => 'Automated')
  end

  def parse_params(params_string)
    Hash[params_string.scan(/([^\s\=]+)\=([^\s\=]+)/)]
  end
end

class OSMonitorWikiPage
  attr_accessor :text
  attr_accessor :segments

  def initialize
    self.segments = []
  end

  def get_segments(type)
    @segments.select {|segment| segment.type == type}
  end
end


# Holds information for an OSMonitor segment in a wiki page.
class OSMonitorWikiPageSegment
  attr_accessor :all
  attr_accessor :beginning
  attr_accessor :ending
  attr_accessor :type
  attr_accessor :params

  def to_report_request
    request = ReportRequest.new
    request.report_type = type
    request.country = params['country']
    request.ids = params['refs']
    request.id_prefix = params['ref_prefix']
    request
  end
end

end
