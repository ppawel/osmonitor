require 'rgeo'

require 'config'
require 'osmonitor/core'

module OSMonitor
module RoadReport

class Road < OSMonitor::Entity

  def self.parse_ref(ref)
    ref.scan(/^([^\d\.]*)(.*)$/)
    return $1, $2
  end

  attr_accessor :other_relations
  attr_accessor :ways
  attr_accessor :nodes
  attr_accessor :graph
  attr_accessor :comps
  attr_accessor :row

  def initialize(country, input)
    self.country = country
    self.input = input
    self.nodes = {}
    self.ways = {}
    self.other_relations = []
    self.comps = []
  end

  def ref
    @input['ref']
  end

  def empty?
    graph.empty?
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

  def correct_num_comps
    return @relation.tags['osmonitor:road_components'].to_i if @relation and @relation.tags['osmonitor:road_components']
    1
  end

  def last_update
    last_updated_way = ways.values.max_by {|way| way.last_update.timestamp}
    last_updated_item = [last_updated_way, @relation].max_by {|item| item.nil? ? '1111-11-11 11:11' : item.last_update.timestamp}
    return last_updated_item.last_update if last_updated_item
  end

  def find_sister_component(c)
    @comps.select {|component| c.oneway? and component.oneway? and c != component and (c.segment_length - component.segment_length).abs < 2222}
  end

  def length
    return nil if !all_components_have_roundtrip? or empty?
    meters = 0
    meters_oneway = 0
    comps.each {|comp| meters += comp.length if find_sister_component(comp).empty?}
    comps.each {|comp| meters_oneway += comp.length if !find_sister_component(comp).empty?}
    return (meters + meters_oneway / 2.0) / 1000.0 if meters
  end

  def approx_length
    return nil if empty?
    meters = 0
    meters_oneway = 0
    comps.each {|comp| meters += comp.segment_length if find_sister_component(comp).empty?}
    comps.each {|comp| meters_oneway += comp.segment_length if !find_sister_component(comp).empty?}
    return (meters + meters_oneway / 2.0) / 1000.0 if meters
  end

  def all_components_have_roundtrip?
    comps.detect {|c| !c.has_complete_roundtrip?}.nil?
  end

  # Determines whether given way should be skipped during road graph creation.
  def skip_way?(way)
    # Ferry routes are an exception to accommodate roads in Poland :)
    return true if !way.tags.has_key?('highway') and way.tags['route'] != 'ferry'

    # Skip ways that are in construction (don't exist) - but note that ways that are repaired are NOT skipped
    return true if way.tags['highway'] == 'proposed' #or way.tags['highway'] == 'construction'

    # Skip ways that exist and are not accessible.
    #return true if way.tags['access'] == 'no' and way.tags['highway'] != 'construction'

    # Otherwise the way is cool.
    return false
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

      add_way_to_graph(graph, way_rows)
    end
  end

  def calculate_components
    graph.to_undirected.connected_components_nonrecursive.each do |comp|
      # Use Set here because include? method is much faster on Set than Array.
      induced = graph.induced_subgraph(Set.new(comp.vertices))
      component = RoadComponent.new(self, induced)
      # Ignore components in construction
      next if component.in_construction?
      @comps << component
    end
  end

  def find_super_components
    new_comps = []
    skip_those = []

    @comps.each do |comp|
      next if skip_those.include?(comp)
      sister = find_sister_component(comp)

      if sister.empty?
        new_comps << comp
      else
        skip_those << sister[0]
        supercomp = RoadSuperComponent.new(comp, sister[0])
        new_comps << supercomp
        @@log.debug "   found super component: #{supercomp})"
      end
    end

    @comps = new_comps
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

      node1 = add_node(Node.new(a_node_id, a['node_tags'], a['node_wkb'])) if !node1
      node2 = add_node(Node.new(b_node_id, b['node_tags'], b['node_wkb'])) if !node2

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
    way = Way.new(row['way_id'].to_i, row['member_role'], row['way_tags'], row['way_wkb'])
    way.last_update = Changeset.new(row['way_last_update_user_id'].to_i, row['way_last_update_user_name'],
      row['way_last_update_timestamp'], row['way_last_update_changeset_id'])
    way.relation = @relation
    way
  end

  def geom_wkt
    return '' if @ways.empty?
    ways_wkt = @ways.values.reduce('') {|result, way| result + way.linestring.as_text + ','}[0..-2]
    "GEOMETRYCOLLECTION(#{ways_wkt})"
  end

  def comps_wkt
    return '' if @comps.empty?
    all_comp_ways = []
    @comps.each {|comp| all_comp_ways += comp.ways}
    ways_wkt = all_comp_ways.uniq.reduce('') {|result, way| result + way.linestring.as_text + ','}[0..-2]
    "GEOMETRYCOLLECTION(#{ways_wkt})"
  end
end

# Representa a road component. A road component is a connected subgraph of a road.
class RoadComponent
  include OSMonitorLogger

  attr_accessor :road
  attr_accessor :graph
  attr_accessor :oneway
  attr_accessor :exit_nodes
  attr_accessor :roundtrip

  def initialize(road, graph)
    self.road = road
    self.graph = graph
    self.roundtrip = nil
    self.oneway = calculate_oneway

    undirected_graph = graph.to_undirected
    self.exit_nodes = undirected_graph.vertices.select {|v| undirected_graph.out_degree(v) <= 1}
  end

  def beginning_nodes
    return [] if !roundtrip
    roundtrip.beginning_nodes
  end

  def end_nodes
    return [] if !roundtrip
    roundtrip.end_nodes
  end

  def length
    roundtrip.length if roundtrip
  end

  def segment_length
    graph.labels.values.uniq.reduce(0) {|total, segment| total + segment.length}
  end

  def found_beginning_and_end?
    !self.beginning_nodes.empty? and !self.end_nodes.empty?
  end

  # Decides if this component is in construction
  def in_construction?
    ways.detect {|w| !w.in_construction?}.nil?
  end

  # Calculates beginning and end of this road component and tries to find a roundtrip.
  def calculate
    roundtrips = []
    closest_to_all = closest_nodes_to_all(graph.vertices, @exit_nodes, 666)

    roundtrips << find_roundtrip(Array.new(@exit_nodes))
    roundtrips << find_roundtrip(Array.new(@exit_nodes), true)
    roundtrips << find_roundtrip(Array.new(@exit_nodes) + closest_to_all)
    roundtrips << find_roundtrip(Array.new(@exit_nodes) + closest_to_all, true)

    @@log.debug " roundtrips = #{roundtrips}"
    @roundtrip = select_best_roundtrip(roundtrips)
    @@log.debug " best_roundtrip = #{@roundtrip}"
  end

  def select_best_roundtrip(roundtrips)
    roundtrips.max
  end

  def find_roundtrip(nodes, expand = false)
    distance_graph = prepare_distance_graph(nodes)
    expand_candidates(distance_graph, nodes) if expand
    beginning, ends = find_beginning_and_end(distance_graph, nodes)
    calculate_roundtrip(beginning, ends)
  end

  def find_beginning_and_end(distance_graph, candidate_nodes)
    beginning = []
    ends = []
    max_pair = distance_graph.furthest_pair_of_nodes(candidate_nodes)

    if max_pair
      beginning = [max_pair[0]] + closest_nodes(candidate_nodes, max_pair[0])
      beginning.uniq!
      ends = [max_pair[1]] + closest_nodes(candidate_nodes, max_pair[1]) - beginning
      ends.uniq!
    end

    return beginning, ends
  end

  def prepare_distance_graph(candidate_nodes)
    distance_graph = graph.to_undirected

    candidate_nodes.each do |node|
      closest = closest_nodes(candidate_nodes, node)
      #puts "closest(#{node}) = #{closest}"
      closest.each do |close_node|
        next if node == close_node
        #@@log.debug "  adding edge #{node}-#{close_node} (dist = #{distance_between(node, close_node)})"
        distance_graph.add_edge(node, close_node, WaySegment.new(nil, node, close_node, 0))
      end
    end

    distance_graph
  end

  def expand_candidates(distance_graph, nodes)
    nodes.clone.each do |node|
      max_node, dist = distance_graph.max_dist(node)
      #puts "max_dist(#{node}) = #{max_node}, #{dist}"
      nodes << max_node if max_node
    end
    nodes.uniq!
  end

  def find_path(from_nodes, to_nodes)
    failed = nil

    from_nodes.each do |node1|
      to_nodes.each do |node2|
        dist = graph.dist(node1, node2)

        if dist
          return RoadComponentPath.new(node1, node2, true, segments(graph.path(node1, node2)))
        else
          new_failed = calculate_failed_path(node1, node2)
          failed = new_failed if !failed or new_failed.length > failed.length
        end
      end
    end

    if !failed and @road.nodes.size >= 2
      failed = RoadComponentPath.new(@road.nodes[@road.nodes.keys[0]], @road.nodes[@road.nodes.keys[1]], false, [])
    end

    failed
  end

  def calculate_roundtrip(beginning, ends)
    forward_path = find_path(beginning, ends)
    backward_path = find_path(ends, beginning)

    result = RoadComponentRoundtrip.new(self, beginning, ends, forward_path, backward_path)
    result.failed_paths << forward_path if forward_path and !forward_path.complete
    result.failed_paths << backward_path if backward_path and !backward_path.complete

    result
  end

  def calculate_failed_path(node1, node2)
    it = RGL::PathIterator.new(road.graph, node1, node2)
    it.set_to_end

    segments = []
    it.path.each_cons(2) {|n1, n2| segments << graph.get_label(n1, n2)}
    RoadComponentPath.new(node1, node2, false, segments.select {|s| s})
  end

  def segments(path)
    segments = []
    path.each_cons(2) {|node1, node2| segments << road.graph.get_label(node1, node2) if road.graph.get_label(node1, node2)}
    segments
  end

  def ways
    @graph.labels.values.uniq.collect {|segment| segment.way}.uniq.select {|w| !w.nil?}
  end

  # Returns a list of nodes that are within max_dist of given node.
  def closest_nodes(nodes, node_from, max_dist = nil)
    max_dist = [segment_length * 0.10, 2222].min if !max_dist
    closest = []
    nodes.each do |node_to|
      d = node_from.distance(node_to)
      closest << [node_to, d] if d and d <= max_dist
    end
    closest.sort_by! {|x| x[1]}
    closest.collect {|x| x[0]}.uniq
  end

  # Returns a list of nodes that are within max_dist of given nodes.
  def closest_nodes_to_all(nodes, nodes_from, max_dist = nil)
    closest = []
    nodes_from.each do |node_from|
      closest += closest_nodes(nodes, node_from, max_dist)[0..5]
    end
    closest.uniq
  end

  def has_complete_roundtrip?
    roundtrip and roundtrip.complete?
  end

  # Determines if this component is oneway - meaning that it is (mostly) composed of oneway ways.
  def calculate_oneway
    return false if !graph.acyclic?
    segments = graph.labels.values
    all_count = segments.select {|s| s}.size
    oneway_count = segments.select {|s| s and s.way.oneway?}.size
    return oneway_count.to_f / all_count.to_f >= 0.9
  end

  def oneway?
    @oneway
  end

  def wkt_points
    points = []
    graph.labels.values.each do |segment|
      next if !segment
      points << segment.from_node.point_wkt
      points << segment.to_node.point_wkt
    end
    points
  end

  def to_s
    "RoadComponent(size = #{graph.num_vertices}, length = #{length})"
  end
end

# Super component is just an aggregation of two components, e.g. for a highway that has two separate components in different directions.
# For purposes of reporting they should be considered one (super) component.
class RoadSuperComponent < RoadComponent
  attr_accessor :subcomp1
  attr_accessor :subcomp2

  def initialize(comp1, comp2)
    self.subcomp1 = comp1
    self.subcomp2 = comp2
  end

  def graph; @subcomp1.graph end
  def beginning_nodes; @subcomp1.beginning_nodes + @subcomp2.beginning_nodes end
  def end_nodes; @subcomp1.end_nodes + @subcomp2.end_nodes end
  def exit_nodes; @subcomp1.exit_nodes + @subcomp2.exit_nodes end
  def segment_length; @subcomp1.segment_length end
  def ways; (@subcomp1.ways + @subcomp2.ways).uniq end

  def roundtrip
    RoadComponentRoundtrip.new(self, beginning_nodes, end_nodes, forward_path, backward_path)
  end

  def forward_path
    path1 = @subcomp1.roundtrip.get_complete_path
    path2 = @subcomp2.roundtrip.get_complete_path
    return path1 if path1
    return path2 if path2
  end

  def backward_path
    path1 = @subcomp1.roundtrip.get_complete_path
    path2 = @subcomp2.roundtrip.get_complete_path
    return path1 if path1 and path1 != forward_path
    return path2 if path2 and path2 != forward_path
  end

  def to_s
    "RoadSuperComponent(subcomp1 = #{subcomp1}, subcomp2 = #{subcomp2})"
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
  attr_accessor :beginning_nodes
  attr_accessor :end_nodes
  attr_accessor :forward_path
  attr_accessor :backward_path
  attr_accessor :failed_paths

  def initialize(component, beginning_nodes, end_nodes, forward_path, backward_path)
    self.component = component
    self.beginning_nodes = beginning_nodes
    self.end_nodes = end_nodes
    self.forward_path = forward_path
    self.backward_path = backward_path
    self.failed_paths = []
  end

  def complete?
    # If the road component is oneway - only one path is needed in the roundtrip.
    return ((@forward_path and @forward_path.complete) or (@backward_path and @backward_path.complete)) if @component.oneway?
    # Otherwise both paths are needed.
    @forward_path and @forward_path.complete and @backward_path and @backward_path.complete
  end

  def get_complete_path
    return @forward_path if @forward_path.complete
    return @backward_path if @backward_path.complete
  end

  def length
    return nil if !complete?
    return @forward_path.length if @forward_path and @forward_path.complete and @component.oneway?
    return @backward_path.length if @backward_path and @backward_path.complete and @component.oneway?
    (@forward_path.length + @backward_path.length) / 2.0
  end

  def <=>(other_roundtrip)
    return length <=> other_roundtrip.length if complete? and other_roundtrip.complete?
    return 1 if complete?
    return -1 if other_roundtrip.complete?
    return (@forward_path.length + @backward_path.length) <=> (other_roundtrip.forward_path.length + other_roundtrip.backward_path.length)
    0
  end

  def to_s
    "RoadComponentRoundtrip(complete = #{complete?.inspect}, length = #{length.inspect}, forward = #{forward_path}, backward = #{backward_path})"
  end
end

end
end
