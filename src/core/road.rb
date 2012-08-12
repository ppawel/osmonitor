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

class Road
  attr_accessor :ref_prefix
  attr_accessor :ref_number
  attr_accessor :relation
  attr_accessor :other_relations
  attr_accessor :ways
  attr_accessor :nodes
  attr_accessor :graph
  attr_accessor :comps

  def initialize(ref_prefix, ref_number)
    self.ref_prefix = ref_prefix
    self.ref_number = ref_number
    self.nodes = {}
    self.ways = {}
    self.other_relations = []
    self.comps = []
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

  def num_comps
    @comps.size
  end

  def length
    return if !comps[0] or !comps[0].longest_complete_path
    comps[0].longest_complete_path.length / 1000.0
  end

  def has_incomplete_paths?
    !comps.detect {|c| c.has_incomplete_paths?}.nil?
  end

  def create_graph(data)
    @graph = RGL::DirectedAdjacencyGraph.new

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

      add_way_to_graph(@graph, way_rows)
    end

    @comps = @graph.to_undirected.connected_components_nonrecursive.collect {|c| RoadComponent.new(self, c)}
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

      node1 = add_node(Node.new(a_node_id, a['node_tags'], a['node_geom'])) if !node1
      node2 = add_node(Node.new(b_node_id, b['node_tags'], b['node_geom'])) if !node2

      segment = way.add_segment(node1, node2, a['node_dist_to_next'].to_f)

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
  attr_accessor :end_node_dijkstras
  attr_accessor :paths

  def initialize(road, graph)
    self.road = road
    self.graph = graph
    self.end_nodes = graph.vertices.select {|v| graph.out_degree(v) <= 1}
    self.end_node_dijkstras = {}
    self.paths = []
  end

  def calculate_paths
    @end_nodes.each do |node|
      it = RGL::DijkstraIterator.new(road.graph, node, nil)
      it.go
      @end_node_dijkstras[node] = it
    end

    calculate_roundtrips
  end

  def segments(end_node, some_node)
    path = @end_node_dijkstras[end_node].to(some_node)
    segments = []
    #puts "path = #{path.inspect}"
    #puts road.graph
    path.each_cons(2) {|node1, node2| segments << road.graph.get_label(node1, node2)}
    segments
  end

  def dist(end_node, some_node)
    @end_node_dijkstras[end_node].dist[some_node]
  end

  # Returns a node that is the furthest away from given end node.
  def furthest(end_node)
    @end_nodes.max_by {|end_node2| @end_node_dijkstras[end_node].dist[end_node2] ? @end_node_dijkstras[end_node].dist[end_node2] : -1}
  end

  # Returns end nodes sorted by distance from an end node to given node.
  def closest_end_nodes(node, max_dist = 2 << 64)
    @end_node_dijkstras.sort_by {|end_node, it| it.dist[node].nil? ? 2 << 64 : it.dist[node]}.collect {|end_node, it| end_node}
  end

  def calculate_roundtrips
    @end_nodes.each do |end_node|
      furthest = furthest(end_node)
      next if end_node == furthest

      dist = dist(end_node, furthest)
      closest_to_furthest = closest_end_nodes(furthest)
      closest_to_end_node = closest_end_nodes(end_node)
      roundtrip_dist = nil

      closest_to_furthest.each do |node1|
        next if node1 == end_node
        closest_to_end_node.each do |node2|
          next if node1 == node2
          roundtrip_dist = dist(node1, node2)
          puts "tried #{node1}->#{node2}: #{roundtrip_dist} (dist = #{dist})"

          if !roundtrip_dist.nil? and roundtrip_dist > 0 and ((dist - roundtrip_dist).abs < 2222)
            paths << RoadComponentPath.new(end_node, furthest, true, segments(end_node, furthest))
            paths << RoadComponentPath.new(node1, node2, true, segments(node1, node2))
          else
            # Target cannot be reached from source - so we do a BFS search to find the partial path (useful for displaying on the map).
            it = RGL::PathIterator.new(road.graph, node1, node2)
            it.set_to_end
            puts "failed #{node1}->#{node2}: bfs size = #{it.path.size}"
            segments = []
            if !it.path.empty?
              it.path.each_cons(2) {|n1, n2| segments << @graph.get_label(n1, n2)}
              @paths << RoadComponentPath.new(node1, node2, false, segments.select {|s| s})
            end
          end
        end
      end
    end
  end

  def wkt_points
    points = []
    @graph.labels.values.each do |segment|
      next if !segment
      points << segment.from_node.point_wkt
      points << segment.to_node.point_wkt
    end
    points
  end

  def longest_complete_path
    complete_paths.max {|p1, p2| p1.length <=> p2.length}
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

  def wkt_points
    points = []
    @segments.each do |segment|
      points << segment.from_node.point_wkt
      points << segment.to_node.point_wkt
    end
    points
  end

  def to_s
    "RoadComponentPath(#{from.id}->#{to.id}, #{length}, #{complete})"
  end
end
