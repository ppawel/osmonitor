require "./config"
require "./wiki"

def get_relation_network(prefix)
  return $road_type_network_tag[prefix]
end

class Road
  attr_accessor :ref_prefix
  attr_accessor :ref_number
  attr_accessor :relation
  attr_accessor :other_relations
  attr_accessor :row
  attr_accessor :relation_ways
  attr_accessor :ways
  attr_accessor :input_length
  attr_accessor :osm_length
  attr_accessor :nodes

  def initialize(ref_prefix, ref_number, row)
    self.ref_prefix = ref_prefix
    self.ref_number = ref_number
    self.row = row
    self.other_relations = []
    self.relation_ways = []
    self.ways = []
    self.input_length = nil
    self.osm_length = nil
    self.nodes = {}
  end

  def get_osm_length
    relation['length'].to_i / 1000 if relation
  end

  def length_diff
    return (get_osm_length - input_length).abs.to_i
  end

  def has_proper_length
    return nil if !relation or !input_length
    return length_diff < 2
  end

  def get_network
    return (relation and relation["tags"]["network"])
  end

  def get_proper_network
    return get_relation_network(ref_prefix)
  end

  def has_proper_network
    return get_network == get_proper_network 
  end

  def has_many_relations
    return !other_relations.empty?
  end

  def has_many_covered_relations
    return other_relations.select {|x| x['covered'] == 't'}.size > 0
  end

  def percent_with_lanes
    return if not relation_ways or relation_ways.empty?
    return ((relation_ways.select { |way| way['tags'].has_key?('lanes') }.size / relation_ways.size.to_f) * 100).to_i
  end

  def percent_with_maxspeed
    return if not relation_ways or relation_ways.empty?
    return ((relation_ways.select { |way| way['tags'].has_key?('maxspeed') }.size / relation_ways.size.to_f) * 100).to_i
  end

  # Returns a list of strings representing the "ref" tag. This is a list because sometimes this tag contains many values, e.g. "34; S1".
  def get_refs(way)
    return [] if !way['tags'].has_key?('ref')
    return way['tags']['ref'].split(/(;|,)/).collect {|ref| ref.strip}
  end

  # Finds ways without "highway" tag (exception is ferry ways, see http://www.openstreetmap.org/browse/way/23541424).
  def ways_without_highway_tag
    return [] if not relation_ways or relation_ways.empty?
    return relation_ways.select { |way| !way['tags'].has_key?('highway') and (!way['tags'].has_key?('route') or way['tags']['route'] != 'ferry') }
  end

  # Finds ways without "ref" tag or with wrong tag value.
  def ways_with_wrong_ref
    return [] if not relation_ways or relation_ways.empty?
    return relation_ways.select { |way| !way['tags'].has_key?('ref') or !get_refs(way).include?(eval($road_type_ref_tag[ref_prefix], binding())) }
  end

  def add_node(node_id, neighbors)
    if !nodes.has_key?(node_id)
      nodes[node_id] = Node.new(node_id, neighbors)
    else
      nodes[node_id].neighbors += neighbors
    end
  end

  def connectivity
    has_roles = nodes.select {|id, node| node.has_neighbor_with_role('backward') or node.has_neighbor_with_role('forward')}.size > 0

    if has_roles
      backward = road_walk(nodes, 'backward')
      forward = road_walk(nodes, 'forward')
      return backward, forward
    else
      return road_walk(nodes), nil
    end
  end
end

class RoadStatus
  attr_accessor :road
  attr_accessor :issues
  attr_accessor :backward
  attr_accessor :forward

  def initialize(road)
    self.road = road
    self.issues = []
  end

  def add_error(name, data = {})
    issues << RoadIssue.new(:ERROR, name, data)
  end

  def add_warning(name, data = {})
    issues << RoadIssue.new(:WARNING, name, data)
  end

  def add_info(name, data = {})
    issues << RoadIssue.new(:INFO, name, data)
  end

  def get_issues(type)
    return issues.select {|issue| issue.type == type}
  end

  def connected
    return (backward == 1 and (forward == 1 or forward.nil?))
  end

  def validate
    add_error('no_relation') if !road.relation

    return if !road.relation

    add_error('has_many_covered_relations') if road.has_many_covered_relations

    if !road.ways_without_highway_tag.empty?
      add_error('has_ways_without_highway_tag', {:ways => road.ways_without_highway_tag})
    end

    #if !road.ways_with_wrong_ref.empty?
    #  add_error('ways_with_wrong_ref', {:ways => road.ways_with_wrong_ref})
    #end

    #add_warning('ways_not_in_relation', {:ways => road.ways}) if road.ways.size > 0

    add_warning('relation_disconnected') if !connected
    add_warning('wrong_network') if !road.has_proper_network
    add_warning('wrong_length') if !road.has_proper_length.nil? and !road.has_proper_length
    add_info('osm_length', road.get_osm_length)
    add_info('percent_with_lanes', road.percent_with_lanes)
    add_info('percent_with_maxspeed', road.percent_with_maxspeed)
  end
end

class RoadIssue
  attr_accessor :name
  attr_accessor :type
  attr_accessor :data

  def initialize(type, name, data)
    self.type = type
    self.name = name
    self.data = data
  end
end

class RoadReport
  attr_accessor :statuses

  def initialize
    self.statuses = []
  end

  def add_status(status)
    statuses << status
  end

  # Returns percent_green, percent_yellow, percent_red.
  def get_percentages
    green = statuses.select {|status| status.get_issues(:WARNING).size == 0 and status.get_issues(:ERROR).size == 0}.size
    yellow = statuses.select {|status| status.get_issues(:WARNING).size > 0 and status.get_issues(:ERROR).size == 0}.size
    red = statuses.select {|status| status.get_issues(:ERROR).size > 0}.size
    return (green / statuses.size.to_f * 100).to_i, (yellow / statuses.size.to_f * 100).to_i, (red / statuses.size.to_f * 100).to_i
  end
end

# Represents a neighbor relation between two nodes. A node can have multiple neighbors - multiple instance of this class.
# Each neighbor relation points to the neighbor node and contains additional relation info (like way_id or member_role) that
# can be used during graphtraversal. Node neighbor relation is basically an edge (with weights or other info on it) from graph theory.
class NodeNeighbor
  attr_accessor :id
  attr_accessor :way_id
  attr_accessor :way_role
  
  def initialize(id, way_id, way_role)
    self.id = id
    self.way_id = way_id
    self.way_role = way_role
  end
end

# Represents a node in OSM sense. Also holds information about neighboring nodes in OSM sense - nodes that are next to (using sequence_id)
# this node in an OSM way.
class Node
  attr_accessor :id
  attr_accessor :neighbors

  def initialize(id, neighbors)
    self.id = id
    self.neighbors = neighbors
  end

  def has_neighbor_with_role(role)
    return neighbors.select {|n| n.way_role == role}.size > 0
  end

  def backward?
    return (has_neighbor_with_role('backward') or all?)
  end

  def forward?
    return (has_neighbor_with_role('forward') or all?)
  end

  def all?
    return has_neighbor_with_role('')
  end

  def can_go_to(neighbor, walk_role)
    return (walk_role.nil? or neighbor.way_role == '' or neighbor.way_role == walk_role)
  end
end

def road_walk(nodes, role = nil)
  return 0 if nodes.empty?
  visited = {}
  skipped_nodes = 0
  i = 0

  #puts nodes

  while (skipped_nodes + visited.size < nodes.size)
    next_root = nil

    (nodes.keys - visited.keys).each do |candidate_id|
      if nodes[candidate_id].all? or nodes[candidate_id].has_neighbor_with_role(role)
        next_root = candidate_id
        break
      end

      skipped_nodes += 1
    end

    break if next_root.nil?

    i += 1

    #puts "ble = #{skipped_nodes + visited.size}"

    visited[next_root] = i
    queue = [next_root]

    puts "------------------ INCREASING i to #{i}, role = #{role}, next_root = #{next_root}"

    while(!queue.empty?)
      node_id = queue.pop()
      node = nodes[node_id]
      #puts "visiting #{nodes[node_id].inspect}"
      #puts nodes[node]
      node.neighbors.each do |neighbor|
        #puts "neighbor #{neighbor.id} - #{node.can_go_to(neighbor, role).to_s.inspect}"
        if !visited.has_key?(neighbor.id) and nodes.include?(neighbor.id) and node.can_go_to(neighbor, role)
           queue.push(neighbor.id)
           visited[neighbor.id] = i
        end
      end
    end
  end

  components = {}

  visited.each do |node, component|
    components[component] = [] if !components.has_key?(component)
    components[component] << node
  end

  components.each {|id, n| puts "#{id} = #{n.size} node(s)"}

  return i
end
