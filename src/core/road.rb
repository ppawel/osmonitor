require 'config'
require 'core/osm'
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

  def initialize(ref_prefix, ref_number)
    self.ref_prefix = ref_prefix
    self.ref_number = ref_number
    self.nodes = {}
    self.ways = {}
    self.other_relations = []
    self.relation_comps = []
    self.ref_comps = []
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
    node
  end

  def get_way(way_id)
    return ways[way_id]
  end

  def add_way(way)
    @ways[way.id] = way
    way
  end

  def relation_num_comps
    @relation_comps.size
  end

  def create_relation_graph(data)
    @relation_graph, @relation_comps = create_graph(data)
    @relation_comps.each {|c| c.calculate_paths}
  end

  def create_ref_graph(data)
    @ref_graph, @ref_comps = create_graph(data)
    @ref_comps.each {|c| c.calculate_paths}
  end

  def length
    return if !relation_comps[0] or !relation_comps[0].longest_path
    relation_comps[0].longest_path.length / 1000.0
  end

  def has_incomplete_paths?
    !relation_comps.detect {|c| c.has_incomplete_paths?}.nil?
  end

  protected
  
  def create_graph(data)
    graph = RGL::DirectedAdjacencyGraph.new

    prev_way_id = nil
    i = 0

    while data[i] do
      way_id = data[i]['way_id'].to_i
      way_rows = []

      while data[i] and data[i]['way_id'].to_i == way_id do
        way_rows << data[i]
        i += 1
      end
      
      add_way_to_graph(graph, way_rows)
    end

    return graph, graph.to_undirected.connected_components_nonrecursive.collect {|c| RoadComponent.new(self, c)}
  end

  def add_way_to_graph(graph, way_rows)
    way, lengths = create_way(way_rows[0]), create_way_lengths(way_rows[0])
    way.lengths = lengths

    i = 0

    way_rows.each_cons(2) do |a, b|
      next if is_link?(a['member_role'], a['way_tags'])

      a_node_id = a['node_id'].to_i
      b_node_id = b['node_id'].to_i

      node1 = get_node(a_node_id)
      node2 = get_node(b_node_id)

      node1 = add_node(Node.new(a_node_id, a['node_tags'])) if !node1
      node2 = add_node(Node.new(b_node_id, b['node_tags'])) if !node2

      graph.add_vertex(node1)
      graph.add_vertex(node2)
      graph.add_edge(node1, node2, [way, lengths[i]])
      graph.add_edge(node2, node1, [way, lengths[i]]) if !way.oneway?

      i += 1
    end

    add_way(way)
  end
  
  def create_way(row)
    way = Way.new(row['way_id'].to_i, row['member_role'], row['way_tags'])
    way.geom = row['way_geom']
    way.length = row['way_length'].to_f if row['way_length'] # Used in integration tests.
    way.in_relation = !row['relation_id'].nil?
    way
  end

  def create_way_lengths(row)
    return [] if !row['way_geom']
    lengths = []
    points = RGeo::Geographic.spherical_factory().parse_wkt(row['way_geom']).points
    points.each_cons(2) {|p1, p2| lengths << p1.distance(p2)}
    lengths
  end

  def ble
    # First, we create Node objects and add them to the graph as vertices.

    data.each do |row|
      next if is_link?(row['member_role'], row['way_tags'])

      node_id = row['node_id'].to_i
      node = get_node(node_id)

      next if node

      node = Node.new(node_id, row['node_tags'])
      add_node(node)
    end

    return graph, graph.to_undirected.connected_components_nonrecursive.collect {|c| RoadComponent.new(self, c)}
  end
end

class RoadComponent
  attr_accessor :road
  attr_accessor :graph
  attr_accessor :end_nodes
  attr_accessor :paths

  def initialize(road, graph)
    self.road = road
    self.graph = graph
    self.end_nodes = graph.vertices.select {|v| graph.out_degree(v) <= 1}
    self.paths = []
  end

  def calculate_paths
    @end_nodes.each_pair do |a, b|
      it = RGL::PathIterator.new(road.relation_graph, a, b, 100000)
      it.set_to_end
      puts it.path.inspect
      path = it.path.collect {|edge| road.relation_graph.get_label(edge[0], edge[1])[0]}.uniq
      @paths << RoadComponentPath.new(a, b, it.found_path, path)
    end

    # Remove empty paths - don't need them!
    @paths.select! {|p| p.length and p.length > 0}

    # Sort by length, it's more useful during display.
    @paths.sort! {|p1, p2| -(p1.length <=> p2.length)}
  end

  def longest_path
    @paths.max {|p1, p2| p1.length <=> p2.length}
  end

  def has_complete_paths?
    complete_paths.size > 0
  end

  def has_incomplete_paths?
    paths.select {|p| !p.complete}.size > 0
  end

  def complete_paths
    paths.select {|p| p.complete}
  end
end

class RoadComponentPath
  attr_accessor :from
  attr_accessor :to
  attr_accessor :complete
  attr_accessor :length
  attr_accessor :ways

  def initialize(from, to, complete, ways)
    self.from = from
    self.to = to
    self.complete = complete
    self.ways = ways
    self.length = ways.reduce(0) {|s, w| w.length ? s + w.length : s}
  end

  def wkt
    ways.reduce('') {|s, w| s + w.geom + ','}[0..-2]
  end

  def to_s
    "RoadComponentPath(#{from.id}->#{to.id}, #{length}, #{complete})"
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
  # Finds *any* path from u to v.
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
      @found_path = true if v == @target
    end
  end

  # Finds shortest paths from u to all other vertices using the Dijkstra algorithm.
  class DijkstraIterator < BFSIterator
    attr_accessor :dist
    attr_accessor :prev
    attr_accessor :paths
    attr_accessor :found_path

    def initialize(graph, u)
      self.dist = {u => 0.0}
      self.path = []
      self.found_path = false
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
