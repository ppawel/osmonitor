require 'config'
require 'elogger'
require 'core'
require 'road_manager'

class BrowseController < ApplicationController
  def road
    @conn = PGconn.open( :host => $config['host'], :dbname => $config['dbname'], :user => $config['user'], :password => $config['password'] )
    @road = nil
    road_manager = OSMonitor::RoadManager.new(@conn)

    params[:ref].scan(/([^\d]+)(\d+)/i) do |m|
      @road = road_manager.load_road($1, $2)
    end

    @all_ways_wkt = []
    @mark_points_all = []

    log_time " wkt" do
      @all_ways_wkt = @road.ways.values.reduce('') {|s, w| s + w.geom + ','}[0..-2]
      @mark_points_all = @road.relation_comps.collect {|c| c.end_nodes}.flatten.collect {|node| road_manager.get_node_xy(node.id)}
    end
  end
end
