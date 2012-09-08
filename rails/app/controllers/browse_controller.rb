require 'config'
require 'osmonitor'

class BrowseController < ApplicationController
  def get_conn
    PGconn.open(:host => $config['host'], :port => $config['port'], :dbname => $config['dbname'], :user => $config['user'], :password => $config['password'])
  end

  def road_report
    @conn = get_conn
    use_cache = params[:use_cache] != 'false'
    road_report_manager = OSMonitor::RoadReport::ReportManager.new(@conn)

    @report = road_report_manager.generate_report(params[:country], [{'ref' => params[:ref]}], use_cache)

    if @report.statuses.empty?
      render :file => "#{Rails.root}/public/404.html", :status => :not_found
      return
    end

    @road = @report.statuses[0].road

    @all_ways_wkt = []
    @mark_points_all = []

    log_time " wkt" do
      @all_ways_wkt = @road.ways.values.reduce('') {|s, w| w.geom ? s + w.geom + ',' : s}[0..-2]
      @mark_points_all = @road.comps.collect {|c| c.end_nodes}.flatten.collect {|node| node.point_wkt}
      @mark_points_all += @road.comps.collect {|c| c.beginning_nodes}.flatten.collect {|node| node.point_wkt}
    end
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

    @road = @report.statuses[0].road

    @all_ways_wkt = []
    @mark_points_all = []

    log_time " wkt" do
      @all_ways_wkt = @road.ways.values.reduce('') {|s, w| w.geom ? s + w.geom + ',' : s}[0..-2]
      @mark_points_all = @road.comps.collect {|c| c.end_nodes}.flatten.collect {|node| node.point_wkt}
      @mark_points_all += @road.comps.collect {|c| c.beginning_nodes}.flatten.collect {|node| node.point_wkt}
    end
  end
end
