require 'config'
require 'road'
require 'model'

class BrowseController < ApplicationController
  def road
    @conn = PGconn.open( :host => $config['host'], :dbname => $config['dbname'], :user => $config['user'], :password => $config['password'] )

    params[:ref].scan(/([^\d]+)(\d+)/i) do |m|
      @road = Road.new($1, $2)
    end

    fill_road_relation(@road, @conn)
    load_road_graph(@road, @conn)

    @mark_points_all = @road.graph.end_nodes(:ALL).collect {|node| get_node_xy(node.id, @conn)}
    @mark_points_backward = @road.graph.end_nodes(:BACKWARD).collect {|node| get_node_xy(node.id, @conn)}
    @mark_points_forward = @road.graph.end_nodes(:FORWARD).collect {|node| get_node_xy(node.id, @conn)}
  end
end
