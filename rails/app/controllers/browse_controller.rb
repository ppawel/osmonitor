require 'config'
require 'osmonitor'

def render_erb(file, country, report = nil, status = nil, issue = nil)
  wiki_to_html(ERB.new(File.read("#{get_erb_path(report.report_request.report_type)}/#{file}"), nil, '<>').result(binding))
end

def get_erb_path(report_type)
  $osmonitor_home_dir + "/erb"
end

def wiki_to_html(text)
  result = text.gsub(/\[([^\s]+) show in OSMonitor\]/, '')
  result = result.gsub(/\[([^\s]+)\s(.*?)\]/, '<a target="_blank" href="\1">\2</a>')
  result = result.gsub(/{{changeset\|(\d+).*?}}/, '<a target="_blank" href="http://www.openstreetmap.org/browse/changeset/\1">\1</a>')
  result
end

class BrowseController < ApplicationController
  def road_report
    road_report_manager = OSMonitor::RoadReport::ReportManager.new(get_conn)
    @report = road_report_manager.generate_report(params[:country], get_input, use_cache)

    if @report.statuses.empty?
      render :file => "#{Rails.root}/public/404.html", :status => :not_found
      return
    end

    @country = params[:country]
    @status = @report.statuses[0]
    @road = @status.entity
  end

  def cycleway_report
    @conn = get_conn
    use_cache = params[:use_cache] != 'false'
    road_report_manager = OSMonitor::CyclewayReport::ReportManager.new(@conn)

    @report = road_report_manager.generate_report(params[:country], [{'ref' => params[:ref]}], use_cache)

    if @report.statuses.empty?
      render :file => "#{Rails.root}/public/404.html", :status => :not_found
      return
    end

    @country = params[:country]
    @status = @report.statuses[0]
    @road = @status.entity

    @all_ways_wkt = []
    @mark_points_all = []

    log_time " wkt" do
      @all_ways_wkt = @road.ways.values.reduce('') {|s, w| w.geom ? s + w.geom + ',' : s}[0..-2]
    end
  end

  def use_cache
    params[:use_cache] != 'false'
  end

  def get_conn
    PGconn.open(:host => $config['host'], :port => $config['port'], :dbname => $config['dbname'], :user => $config['user'], :password => $config['password'])
  end

  def get_input
    input_manager = OSMonitor::InputManager.new
    report_request = OSMonitor::ReportRequest.new
    report_request.report_type = 'ROAD_REPORT'
    report_request.country = params[:country]
    report_request.ids = params[:ref]
    input_manager.load(report_request)
  end
end
