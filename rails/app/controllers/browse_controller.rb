require 'config'
require 'elogger'
require 'core'
require 'report_manager'
require 'road_manager'

class BrowseController < ApplicationController
  def road
    @conn = PGconn.open( :host => $config['host'], :dbname => $config['dbname'], :user => $config['user'], :password => $config['password'] )
    road_manager = OSMonitor::RoadManager.new(@conn)
    report_manager = OSMonitor::ReportManager.new(road_manager, Rails.root + '../src/erb/')

    @report, @report_text = report_manager.generate_road_report(params[:country], [params[:ref]], true)

    if @report.statuses.empty?
      render :file => "#{Rails.root}/public/404.html", :status => :not_found
      return
    end

    @road = @report.statuses[0].road

    @all_ways_wkt = []
    @mark_points_all = []

    log_time " wkt" do
      @all_ways_wkt = @road.ways.values.reduce('') {|s, w| s + w.geom + ','}[0..-2]
      @mark_points_all = @road.comps.collect {|c| c.end_nodes}.flatten.collect {|node| node.point_wkt}
    end
  end
end
