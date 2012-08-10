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

    @components_wkt = []
    @road.relation_comps.each {|comp| @components_wkt << comp.wkt}

    @all_paths_wkt = []
    @road.relation_comps.each {|comp| @all_paths_wkt += comp.paths.collect {|path| path.wkt}}

    @all_ways_wkt = @road.ways.values.reduce('') {|s, w| s + w.geom + ','}[0..-2]
    @mark_points_all = @road.relation_comps.collect {|c| c.end_nodes}.flatten.collect {|node| road_manager.get_node_xy(node.id)}
    #@mark_points_backward = @road.graph.end_nodes(:BACKWARD).collect {|node| get_node_xy(node.id, @conn)}
    #@mark_points_forward = @road.graph.end_nodes(:FORWARD).collect {|node| get_node_xy(node.id, @conn)}
  end
end
