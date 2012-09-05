require 'config'
require 'core/logging'
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
  include OSMonitorLogger

  def self.parse_ref(ref)
    ref.scan(/^([^\d\.]+)(.*)$/)
    return $1, $2
  end

  attr_accessor :country
  attr_accessor :ref_prefix
  attr_accessor :ref_number
  attr_accessor :relation
  attr_accessor :other_relations
  attr_accessor :ways
  attr_accessor :nodes
  attr_accessor :graph
  attr_accessor :comps

  def initialize(country, ref_prefix, ref_number)
    self.country = country
    self.ref_prefix = ref_prefix
    self.ref_number = ref_number
    self.nodes = {}
    self.ways = {}
    self.other_relations = []
    self.comps = []
  end

  def empty?
    @graph.empty?
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

  def num_all_ways
    @ways.size
  end

  def num_ref_ways
    @ways.select {|id, w| w.tags.has_key?('ref')}.size
  end

  def num_relation_ways
    @ways.select {|id, w| w.relation}.size
  end

  def num_comps
    @comps.size
  end

  def num_logical_comps
    @comps.size - (@comps.select {|c| !find_sister_component(c).empty?}.size / 2)
  end

  def correct_num_comps
    return @relation.tags['osmonitor:road_components'].to_i if @relation and @relation.tags['osmonitor:road_components']
    1
  end

  def find_sister_component(c)
    @comps.select {|component| c.oneway? and component.oneway? and (c.segment_length - component.segment_length).abs < 2222}
  end

  def length
    return nil if !all_components_have_roundtrip?
    meters = 0
    meters_oneway = 0
    comps.each {|comp| meters += comp.length if find_sister_component(comp).empty?}
    comps.each {|comp| meters_oneway += comp.length if !find_sister_component(comp).empty?}
    return (meters + meters_oneway / 2.0) / 1000.0 if meters
  end

  def approx_length
    meters = 0
    meters_oneway = 0
    comps.each {|comp| meters += comp.length if comp.length and find_sister_component(comp).empty?}
    comps.each {|comp| meters_oneway += comp.length if comp.length and !find_sister_component(comp).empty?}
    return (meters + meters_oneway / 2.0) / 1000.0 if meters
  end

  def all_components_have_roundtrip?
    comps.detect {|c| !c.has_complete_roundtrip?}.nil?
  end

  # Determines whether given way should be skipped during road graph creation.
  def skip_way?(way)
    # Ferry routes are an exception to accommodate roads in Poland :)
    (!way.tags.has_key?('highway') and way.tags['route'] != 'ferry') or way.tags.has_key?('construction') or
      way.tags['highway'] == 'construction' or way.tags['highway'] == 'proposed' or way.tags['access'] == 'no'
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
  end

  def calculate_components
    @graph.to_undirected.connected_components_nonrecursive.each do |comp|
      # Use Set here because include? method is much faster on Set than Array.
      induced = @graph.induced_subgraph(Set.new(comp.vertices))
      @comps << RoadComponent.new(self, induced)
    end
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
    return if skip_way?(way)

    i = 0

    way_rows.each_cons(2) do |a, b|
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
    way.relation = @relation
    way
  end
end

# Representa a road component. A road component is a connected subgraph of a road.
class RoadComponent
  include OSMonitorLogger

  attr_accessor :road
  attr_accessor :graph
  attr_accessor :undirected_graph
  attr_accessor :oneway
  attr_accessor :end_nodes
  attr_accessor :end_node_dijkstras
  attr_accessor :roundtrip
  attr_accessor :start_point
  attr_accessor :end_point

  def initialize(road, graph)
    self.road = road
    self.graph = graph
    self.undirected_graph = graph.to_undirected
    self.end_nodes = []
    self.end_node_dijkstras = {}
    self.roundtrip = nil
    self.oneway = calculate_oneway
  end

  # Calculates end nodes and puts them in the @end_nodes list.
  def calculate_end_nodes
    @end_nodes = @undirected_graph.vertices.select {|v| @undirected_graph.out_degree(v) <= 1}
    new_end_nodes = []
    max = nil

    @@log.debug " end nodes before expanding (#{end_nodes.size}): #{@end_nodes}"

    @end_nodes.each do |node|
      it = RGL::DijkstraIterator.new(@undirected_graph, node, nil)
      it.go
      @end_node_dijkstras[node] = it

      max_node = max_dist(node)

      if max.nil? or max_node[1] > max[1]
        max = max_node
      end

      new_end_nodes << max_node[0] if max_node
    end

    @@log.debug " new end nodes from expanding (#{new_end_nodes.size}): #{new_end_nodes}"

    @end_nodes += new_end_nodes
    @end_nodes = @end_nodes.uniq

    @end_nodes.each do |node|
      it = RGL::DijkstraIterator.new(@graph, node, nil)
      it.go
      @end_node_dijkstras[node] = it
    end

    @@log.debug " final end nodes (#{end_nodes.size}): #{@end_nodes}"
  end

  # Attemtps to calculate a roundtrip between the beginning and end of the road component. Beginning and end are defined
  # by furthest end nodes. In order to find the roundtrip, two paths (forward and backward) need to be found (unless the road
  # component is oneway then one path is enough) between furthest end nodes. In the process, end nodes closest to the beginning
  # and end one are tried to account for trunk links, multiple oneway end nodes in close proximity etc.
  def calculate_roundtrip
    max_pair, max = furthest_pair_of_end_nodes

    @@log.debug " max_pair = #{max_pair}, max = #{max}"

    if !max_pair
      @@log.debug " Unable to found a pair of end nodes?"
      return
    end

    end_node = max_pair[0]
    furthest = max_pair[1]

    if oneway?
      @@log.debug " Oneway component, not trying to find roundtrip"
      forward_path = RoadComponentPath.new(end_node, furthest, true, segments(end_node, furthest))
      @roundtrip = RoadComponentRoundtrip.new(self, forward_path, nil)
      return
    end

    dist = dist(end_node, furthest)

    forward_path = RoadComponentPath.new(end_node, furthest, true, segments(end_node, furthest))
    backward_path = nil
    failed_paths = []

    closest_to_furthest = closest_end_nodes(furthest)
    closest_to_end_node = closest_end_nodes(end_node)

    @@log.debug " Trying to find roundtrip from #{end_node} (furthest = #{furthest}, closest_to_furthest = #{closest_to_furthest}, closest_to_end_node = #{closest_to_end_node})"

    roundtrip_dist = nil

    @end_nodes.each do |node1|
      next if node1 == end_node

      @end_nodes.each do |node2|
        next if node1 == node2

        roundtrip_dist = dist(node1, node2)
        puts "tried #{node1}->#{node2}: #{roundtrip_dist} (dist = #{dist})"

        if !roundtrip_dist.nil? and roundtrip_dist > 0 and ((dist - roundtrip_dist).abs < 2222)
         @@log.debug " Found backward path: #{node1}-#{node2} (dist = #{dist}, roundtrip_dist = #{roundtrip_dist})"
          backward_path = RoadComponentPath.new(node1, node2, true, segments(node1, node2))
        else
          # Target cannot be reached from source - so we do a BFS search to find the partial path (useful for displaying on the map).
          path = calculate_failed_path(node1, node2)
          @@log.debug " Failed path: #{node1}-#{node2} (path = #{path})"
          failed_paths << path if path
        end

        break if backward_path
      end

      break if backward_path
    end

    @roundtrip = RoadComponentRoundtrip.new(self, forward_path, backward_path)

    if backward_path.nil?
      # Backward path was not found - this means that there is a routing problem or the component is oneway.
      @roundtrip.failed_paths = failed_paths
    end
  end

  def calculate_failed_path(node1, node2)
    it = RGL::PathIterator.new(road.graph, node1, node2)
    it.set_to_end

    if !it.path.empty?
      segments = []
      it.path.each_cons(2) {|n1, n2| segments << @graph.get_label(n1, n2)}
      return RoadComponentPath.new(node1, node2, false, segments.select {|s| s})
    end
  end

  def segments(end_node, some_node)
    path = @end_node_dijkstras[end_node].to(some_node)
    segments = []
    #puts "path = #{path.inspect}"
    #puts road.graph
    path.each_cons(2) {|node1, node2| segments << road.graph.get_label(node1, node2) if road.graph.get_label(node1, node2)}
    segments
  end

  def max_dist(end_node)
    @end_node_dijkstras[end_node].dist.max_by {|end_node, dist| dist}
  end

  def dist(end_node, some_node)
    @end_node_dijkstras[end_node].dist[some_node]
  end

  # Returns an end node that is the furthest away from given end node.
  def furthest(end_node)
    @end_nodes.max_by {|end_node2| @end_node_dijkstras[end_node].dist[end_node2] ? @end_node_dijkstras[end_node].dist[end_node2] : -1}
  end

  # Returns a list of end nodes that are within max_dist to given end node.
  def closest_end_nodes(target_end_node, max_dist = 2 << 64)
    closest = []  
    @end_node_dijkstras.each do |end_node, it|
      dist = dist(end_node, target_end_node)
      dist_reverse = dist(target_end_node, end_node)
      closest << end_node if !dist.nil? and dist < max_dist
      closest << end_node if !dist_reverse.nil? and dist_reverse < max_dist
    end
    closest.uniq
  end

  # Returns a pair of end nodes (and the distance between them) that are furthest apart.
  def furthest_pair_of_end_nodes
    max = -1
    max_pair = nil

    @end_nodes.each do |end_node|
      furthest = furthest(end_node)
      dist = dist(end_node, furthest)

      if dist > max
        max = dist
        max_pair = end_node, furthest
      end
    end

    return max_pair, max
  end

  def length
    roundtrip.length if roundtrip
  end

  def segment_length
    segments = @graph.labels.values
    segments.reduce(0) {|total, segment| total + segment.length}
  end

  def has_complete_roundtrip?
    @roundtrip and @roundtrip.complete?
  end

  # Determines if this component is oneway - meaning that it is (mostly) composed of oneway ways.
  def calculate_oneway
    return false if !@graph.acyclic?
    segments = @graph.labels.values
    all_count = segments.select {|s| s}.size
    oneway_count = segments.select {|s| s and s.way.oneway?}.size
    return oneway_count.to_f / all_count.to_f >= 0.9
  end

  def oneway?
    @oneway
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

  def geom
    ways = @graph.labels.values.collect {|segment| segment.way}.uniq
    wkt = ways.reduce('') {|total, way| total + way.geom.gsub('LINESTRING', '') + ', '}
    "MULTILINESTRING(#{wkt[0..-3]})"
  end
end

# Represents a path within a road component. A path is a set of segments leading from one point to another.
# A path does not have to go all the way from start to end - it can be an incomplete path (useful for tracking
# down navigability problems).
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

# Represents a roundtrip within a road component. Roundtrip is two paths - from A to B and back.
class RoadComponentRoundtrip
  attr_accessor :component
  attr_accessor :forward_path
  attr_accessor :backward_path
  attr_accessor :failed_paths

  def initialize(component, forward_path, backward_path)
    self.component = component
    self.forward_path = forward_path
    self.backward_path = backward_path
    self.failed_paths = []
  end

  def complete?
    @component.oneway? or !@backward_path.nil?
  end

  def length
    return nil if !complete?
    return @forward_path.length if @component.oneway?
    (@forward_path.length + @backward_path.length) / 2.0
  end

  def to_s
    "RoadComponentRoundtrip(#{forward_path}, #{backward_path})"
  end
end
