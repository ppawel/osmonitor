require 'config'
require 'core/osm'
require 'rgeo'
require 'rgl/adjacency'
require 'rgl/implicit'
require 'rgl/connected_components'
require 'rgl/dot'
require 'rgl/topsort'
require 'rgl/base'
require 'rgl/paths'
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
      relation_sequence_id = data[i]['relation_sequence_id']
      way_id = data[i]['way_id'].to_i
      way_rows = []

      while data[i] and data[i]['way_id'].to_i == way_id and data[i]['relation_sequence_id'] == relation_sequence_id do
        way_rows << data[i]
        i += 1
      end
      
      add_way_to_graph(graph, way_rows)
    end

    return graph, graph.to_undirected.connected_components_nonrecursive.collect {|c| RoadComponent.new(self, c)}
  end

  def add_way_to_graph(graph, way_rows)
    return if way_rows.empty?

    way_id = way_rows[0]['way_id'].to_i

    if get_way(way_id)
      # Probably this way is added multiple times to the relation... Skip it for now.
      # See https://github.com/ppawel/osmonitor/issues/13
      puts "WARNING: Way #{way_id} added multiple times to relation?"
      return
    end

    way = create_way(way_rows[0])

    i = 0

    way_rows.each_cons(2) do |a, b|
      #next if is_link?(a['member_role'], a['way_tags'])

      a_node_id = a['node_id'].to_i
      b_node_id = b['node_id'].to_i

      node1 = get_node(a_node_id)
      node2 = get_node(b_node_id)

      node1 = add_node(Node.new(a_node_id, a['node_tags'])) if !node1
      node2 = add_node(Node.new(b_node_id, b['node_tags'])) if !node2

      segment = way.add_segment(node1, node2)

      graph.add_vertex(node1)
      graph.add_vertex(node2)
      graph.add_edge(node1, node2, segment)
      graph.add_edge(node2, node1, segment) if !way.oneway?

      i += 1
    end

    add_way(way)
  end

  def create_way(row)
    way = Way.new(row['way_id'].to_i, row['member_role'], row['way_tags'])
    way.geom = row['way_geom'] if row['way_geom']
    way.set_mock_segment_lengths(row['way_length']) if row['way_length'] # Used in integration tests.
    way.in_relation = !row['relation_id'].nil?
    way
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
    @end_nodes.each_pair do |source, target|
      it = RGL::DijkstraIterator.new(road.relation_graph, source, target)
      it.go
      path = it.to(target)

      if path.size == 1
        # Target cannot be reached from source - so we do a BFS search to find the partial path (useful for displaying on the map).
        it = RGL::PathIterator.new(road.relation_graph, source, target)
        it.set_to_end
        segments = []
        it.path.each_slice(2) {|node1, node2| segments << road.relation_graph.get_label(node1, node2)}
        @paths << RoadComponentPath.new(source, target, false, segments)
      else
        segments = []
        path.each_cons(2) {|node1, node2| segments << road.relation_graph.get_label(node1, node2)}
        @paths << RoadComponentPath.new(source, target, true, segments)
      end
    end

    # Remove empty paths - don't need them!
    @paths.select! {|p| p.length and p.length > 0}

    # Sort by length, it's more useful during display.
    @paths.sort! {|p1, p2| -(p1.length <=> p2.length)}
  end

  def wkt
    segments = @graph.labels.values
    segments.select {|s| s}.reduce('') {|wkt, segment| wkt + segment.line.to_s + ','}[0..-2]
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
  attr_accessor :segments

  def initialize(from, to, complete, segments)
    self.from = from
    self.to = to
    self.complete = complete
    self.segments = segments
    self.length = segments.reduce(0) {|total, segment| segment.length ? total + segment.length : total}
  end

  def wkt
    segments.reduce('') {|wkt, segment| wkt + segment.line.to_s + ','}[0..-2]
    #points = []
    #segments.each do |s|
    #  points << s.line.point_n(0)
    #  points << s.line.point_n(1)
    #end
    #RGeo::Geographic.spherical_factory().line_string(points).to_s
  end

  def to_s
    "RoadComponentPath(#{from.id}->#{to.id}, #{length}, #{complete})"
  end
end
