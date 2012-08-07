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
  attr_accessor :relation_comps
  attr_accessor :ref_comps
  attr_accessor :relation_comp_end_nodes
  attr_accessor :relation_comp_paths
  attr_accessor :relation_comp_lengths

  def initialize(ref_prefix, ref_number)
    self.ref_prefix = ref_prefix
    self.ref_number = ref_number
    self.nodes = {}
    self.ways = {}
    self.other_relations = []
    self.relation_comps = []
    self.ref_comps = []
    self.relation_comp_end_nodes = []
    self.relation_comp_paths = []
    self.relation_comp_lengths = []
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

  def relation_num_comps
    @relation_comps.size
  end

  def create_relation_graph(data)
    @relation_graph, @relation_comps = create_graph(data)
    calculate_comp_lengths
  end

  def create_ref_graph(data)
    @ref_graph, @ref_comps = create_graph(data)
  end

  def length
    relation_comp_lengths[0].max / 1000.0 if relation_comp_lengths[0] and relation_comp_lengths[0].max
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

    return graph, graph.to_undirected.connected_components_nonrecursive
  end

  def get_end_nodes(graph)
    graph.vertices.select {|v| graph.out_degree(v) <= 1}
  end

  def calculate_comp_lengths
    relation_comps.each do |comp|
      end_nodes = get_end_nodes(comp)
      relation_comp_end_nodes << end_nodes
      paths = []
      lengths = []

      end_nodes.each_pair do |a, b|
        it = RGL::PathIterator.new(relation_graph, a, b, 100000)
        it.set_to_end

        path1 = it.path.collect {|edge| edge[0].get_mutual_way(edge[1])}.uniq

        #next if !it.found_path

        paths << path1.uniq
        lengths << path1.reduce(0) {|s, w| s + w.length}
      end

      relation_comp_paths << paths
      relation_comp_lengths << lengths
    end
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
            yield self[j], self[i]
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

    def handle_examine_edge(u, v)
      return if !u or !v
      @path << [u, v]
    end

    def handle_finish_vertex(v)
      #puts "finished #{v} #{@target}"
      @found_path = true if v == @target
    end
  end
end
