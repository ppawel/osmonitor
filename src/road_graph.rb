require './model'

# Because RGL is bundled in OSMonitor!
$:.unshift File.dirname(__FILE__)

require './rgl/adjacency'
require './rgl/implicit'
require './rgl/connected_components'
require './rgl/dot'
require './rgl/topsort'
require './rgl/base'
require './rgl/bidirectional'

class RoadGraph
  attr_accessor :all_graph
  attr_accessor :backward_graph
  attr_accessor :forward_graph
  attr_accessor :graphs
  attr_accessor :road

  def initialize(road)
    self.all_graph = RGL::AdjacencyGraph.new
    self.backward_graph = RGL::AdjacencyGraph.new
    self.forward_graph = RGL::AdjacencyGraph.new
    self.graphs = {:ALL => @all_graph, :BACKWARD => @backward_graph, :FORWARD => @forward_graph}
    self.road = road
  end

  def load(data)
    # OK, now we have a lot of data, need to process it and create a graph! Let's get to work...

    # First, we create Node objects and add them to the graph as vertices.

    data.each do |row|
      node_id = row['node_id'].to_i
      node = road.get_node(node_id)

      next if node

      node = Node.new(node_id, row['node_tags'])
      road.add_node(node)
    end

    # Second, we create Way objects and create edges in the graph between nodes in a way. So a single way can have multiple edges.

    data.each_cons(2) do |a, b|
      a_way_id = a ? a['way_id'].to_i : nil
      b_way_id = b ? b['way_id'].to_i : nil

      way = road.get_way(a_way_id)
      
      if !way
        way = Way.new(a_way_id, a['member_role'], a['way_tags'])
        road.add_way(way)
      end

      next if a_way_id != b_way_id

      node1 = road.get_node(a['node_id'].to_i)
      node2 = road.get_node(b['node_id'].to_i)

      node1.add_way(way)
      node2.add_way(way)

      if way.member_role == 'member' or way.member_role == ''
        all_graph.add_vertex(node1)
        all_graph.add_vertex(node2)
        backward_graph.add_vertex(node1)
        backward_graph.add_vertex(node2)
        forward_graph.add_vertex(node1)
        forward_graph.add_vertex(node2)
        all_graph.add_edge(node1, node2)
        backward_graph.add_edge(node1, node2)
        forward_graph.add_edge(node1, node2)
      end

      if way.member_role == 'backward'
        backward_graph.add_vertex(node1)
        backward_graph.add_vertex(node2)
        backward_graph.add_edge(node1, node2)
      end

      if way.member_role == 'forward'
        forward_graph.add_vertex(node1)
        forward_graph.add_vertex(node2)
        forward_graph.add_edge(node1, node2)
      end
    end
  end

  def end_nodes(graph)
    nodes = []
    graph.vertices.each {|v| nodes << v if graph.out_degree(v) <= 1}
    return nodes
  end

  def suggest_forward_fixes
    suggest_fix_paths(@forward_graph, @backward_graph)
  end

  def suggest_backward_fixes
    suggest_fix_paths(@backward_graph, @forward_graph)
  end

  def suggest_fix_paths(graph_to_fix, graph_with_fixes)
    paths = []

    end_nodes(graph_to_fix).each_pair do |a, b|
      next if !graph_with_fixes.has_vertex?(a) or !graph_with_fixes.has_vertex?(b)
      it = RGL::PathIterator.new(graph_with_fixes, a, b, 10)
      it.set_to_end
      next if !it.found_path

      paths += it.path.collect {|edge| edge[0].get_mutual_way(edge[1])}.uniq.select {|way| way.member_role != ''}
    end

    return paths
  end
end

class Array
    # define an iterator over each pair of indexes in an array
    def each_pair_index
        (0..(self.length-1)).each do |i|
            ((i+1)..(self.length-1 )).each do |j|
                yield i, j
            end
        end
    end
   
    # define an iterator over each pair of values in an array for easy reuse
    def each_pair
        self.each_pair_index do |i, j|
            yield self[i], self[j]
        end
    end
end

module RGL
  class PathIterator < BFSIterator
    attr_accessor :path
    attr_accessor :found_path
    attr_accessor :target
    attr_accessor :stop_after

    def initialize(graph, u, v, stop_after)
      self.path = []
      self.found_path = false
      self.stop_after = stop_after
      self.target = v
      super(graph, u)
    end

    def at_end?
      found_path or @waiting.empty? or @path.size == stop_after
    end

    protected

    def handle_tree_edge(u, v)
      return if !u or !v
      #puts "adding #{u}-#{v}"
      @path << [u, v]
    end

    def handle_finish_vertex(v)
      #puts "finished #{v} #{@target}"
      @found_path = true if v == @target
    end
  end
end
