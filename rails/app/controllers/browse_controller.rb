require 'config'
require 'elogger'
require 'core'
require 'road_manager'

class BrowseController < ApplicationController
  def road
    @conn = PGconn.open( :host => $config['host'], :dbname => $config['dbname'], :user => $config['user'], :password => $config['password'] )
    road_manager = OSMonitor::RoadManager.new(@conn)
    ref_prefix, ref_number = Road.parse_ref(params[:ref])
    @road = road_manager.load_road('PL', ref_prefix, ref_number)

    @all_ways_wkt = []
    @mark_points_all = []

    log_time " wkt" do
      @all_ways_wkt = @road.ways.values.reduce('') {|s, w| s + w.geom + ','}[0..-2]
      @mark_points_all = @road.comps.collect {|c| c.end_nodes}.flatten.collect {|node| node.point_wkt}
    end
  end
end
