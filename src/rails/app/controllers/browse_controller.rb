require 'config'
require 'road'
require 'model'

class BrowseController < ApplicationController
  def road
    @conn = PGconn.open( :host => $config['host'], :dbname => $config['dbname'], :user => $config['user'], :password => $config['password'] )

    params[:ref].scan(/([^\d]+?)(\d+?)/i) do |m|
      @road = Road.new($1, $2)
    end

    fill_road_relation(@road, @conn)
    load_road_graph(@road, @conn)

    @mark_points = @road.graph.end_nodes(:ALL).collect {|node| get_node_xy(node.id, @conn)}
  end
end
