require 'model'
require 'rgeo'
require 'rgl/adjacency'
require 'rgl/implicit'
require 'rgl/connected_components'
require 'rgl/dot'
require 'rgl/topsort'
require 'rgl/base'
require 'rgl/bidirectional'

@rgeo_factory = ::RGeo::Geographic.spherical_factory()
#:projection_proj4 =>
 #  '+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs')

def create_graph(road, data)
  graph = RGL::DirectedAdjacencyGraph.new

  # First, we create Node objects and add them to the graph as vertices.

  data.each do |row|
    node_id = row['node_id'].to_i
    node = road.get_node(node_id)

    road.has_roles = (road.has_roles or !member_role_all?(row['member_role']))

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
      way.geom = a['way_geom']
      #puts a['way_geom']
      way.length = @rgeo_factory.parse_wkt(a['way_geom']).length
      way.relation = road.relation if a['relation_id']
      road.add_way(way)
    end

    next if a_way_id != b_way_id

    node1 = road.get_node(a['node_id'].to_i)
    node2 = road.get_node(b['node_id'].to_i)

    node1.add_way(way)
    node2.add_way(way)

    graph.add_vertex(node1)
    graph.add_vertex(node2)
    graph.add_edge(node1, node2)
    graph.add_edge(node2, node1) if way.tags['oneway'] != 'yes'
  end

  return graph
end

=begin
    paths = []

    ud = dir_graph.to_undirected
    puts ud.vertices.select {|v| ud.out_degree(v) <= 1}.size
    ud.vertices.select {|v| ud.out_degree(v) <= 1}.each_pair do |a, b|
      puts "#{a} -> #{b}"
      it = RGL::PathIterator.new(dir_graph, a, b, 100000)
      it.set_to_end
      if !it.found_path
        it = RGL::PathIterator.new(dir_graph, b, a, 100000)
        it.set_to_end
      end
      next if !it.found_path
      puts "#{a} -> #{b} YEAH"
      paths << it.path.collect {|edge| edge[0].get_mutual_way(edge[1])}.uniq.reduce(0) {|s, w| s + w.length}
    end
    
    puts paths.inspect

  end

  def end_nodes(graph)
    nodes = []
    @graphs[graph].vertices.each {|v| nodes << v if @graphs[graph].out_degree(v) <= 1}
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
=end
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
