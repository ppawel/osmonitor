require 'config'
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

class Road
  attr_accessor :ref_prefix
  attr_accessor :ref_number
  attr_accessor :relation
  attr_accessor :other_relations
  attr_accessor :ways
  attr_accessor :nodes
  attr_accessor :relation_graph
  attr_accessor :ref_graph

  def initialize(ref_prefix, ref_number)
    self.ref_prefix = ref_prefix
    self.ref_number = ref_number
    self.nodes = {}
    self.ways = {}
    self.other_relations = []
  end

  # Returns a list of strings representing the "ref" tag. This is a list because sometimes this tag contains many values, e.g. "34; S1".
  def get_refs(way)
    return [] if !way.tags.has_key?('ref')
    return way.tags['ref'].split(/(;|,)/).collect {|ref| ref.strip}
  end

  def get_node(node_id)
    return nodes[node_id]
  end

  def add_node(node)
    nodes[node.id] = node
  end

  def get_way(way_id)
    return ways[way_id]
  end

  def add_way(way)
    @ways[way.id] = way
  end

  def all_ways
    ways.values.select {|w| w.all?}
  end

  def backward_ways
    ways.values.select {|w| w.backward?}
  end

  def forward_ways
    ways.values.select {|w| w.forward?}
  end
  
  def create_relation_graph(data)
    @relation_graph = create_graph(data)
  end

  def create_ref_graph(data)
    @ref_graph = create_graph(data)
  end

  protected
  
  def create_graph(data)
    graph = RGL::DirectedAdjacencyGraph.new

    # First, we create Node objects and add them to the graph as vertices.

    data.each do |row|
      node_id = row['node_id'].to_i
      node = get_node(node_id)

      next if node

      node = Node.new(node_id, row['node_tags'])
      add_node(node)
    end

    # Second, we create Way objects and create edges in the graph between nodes in a way. So a single way can have multiple edges.

    data.each_cons(2) do |a, b|
      a_way_id = a ? a['way_id'].to_i : nil
      b_way_id = b ? b['way_id'].to_i : nil

      way = get_way(a_way_id)

      if !way
        way = Way.new(a_way_id, a['member_role'], a['way_tags'])
        way.geom = a['way_geom']
        #puts a['way_geom']
        way.length = RGeo::Geographic.spherical_factory().parse_wkt(a['way_geom']).length
        way.in_relation = !a['relation_id'].nil?
        add_way(way)
      end

      next if a_way_id != b_way_id

      node1 = get_node(a['node_id'].to_i)
      node2 = get_node(b['node_id'].to_i)

      node1.add_way(way)
      node2.add_way(way)

      graph.add_vertex(node1)
      graph.add_vertex(node2)
      graph.add_edge(node1, node2)
      graph.add_edge(node2, node1) if way.tags['oneway'] != 'yes'
    end

    return graph
  end

  def get_graph_comps(graph)
    return relation_graph.to_undirected.connected_components_nonrecursive
  end

  def get_end_nodes(graph)
    return comp.vertices.select {|v| comp.out_degree(v) <= 1}
  end
  
  def calculate_paths(graph, end_nodes)
    paths = []
    end_nodes.each_cons(2) do |a, b|
      it = RGL::PathIterator.new(relation_graph, a, b, 100000)
      it.set_to_end
      paths << it.path.collect {|edge| edge[0].get_mutual_way(edge[1])}.uniq.reduce(0) {|s, w| s + w.length}

      next if !it.found_path

      it = RGL::PathIterator.new(relation_graph, b, a, 100000)
      it.set_to_end

      next if !it.found_path

      paths << it.path.collect {|edge| edge[0].get_mutual_way(edge[1])}.uniq.reduce(0) {|s, w| s + w.length}
    end
    
    return paths
  end
  
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
