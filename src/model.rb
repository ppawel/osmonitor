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

  def add_node_role(node_id, member_role)
    nodes[node_id] = Node.new if !nodes.include? node_id
    nodes[node_id].add_role(member_role)
  end

  def add_node_neighs(node_id, neighs)
    nodes[node_id].add_neighs(neighs)
  end

  def connectivity
    has_roles = nodes.select {|id, node| node.roles.include?('backward' )or node.roles.include?('forward')}.size > 0

    if has_roles
      forward = road_walk(nodes, 'forward')
      backward = road_walk(nodes, 'backward')
      #backward = road_walk(Hash[nodes.select {|id, node| node.row['member_role'] == '' or node.row['member_role'] == 'member' or node.row['member_role'] == 'backward' }])
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

class Node
  attr_accessor :roles
  attr_accessor :neighs

  def initialize
    self.neighs = []
    self.roles = []
  end

  def add_neighs(neighs)
    self.neighs += neighs
  end

  def add_role(role)
    roles << role
    #node.row['member_role'] = '' if row['member_role'] == '' or row['member_role'] == 'member'
    #  node.row['member_role'] = '' if node.row['member_role'] == 'forward' and row['member_role'] == 'backward'
    #  node.row['member_role'] = '' if node.row['member_role'] == 'backward' and row['member_role'] == 'forward'
  end

  def backward?
    return (roles.include?('backward') or all?)
  end

  def forward?
    return (roles.include?('backward') or all?)
  end

  def all?
    return (roles.include?('') or roles.include?('member'))
  end
end

def road_walk(nodes, role = nil)
  return 0 if nodes.empty?
  visited = {}
  i = 0

  #puts nodes

  while (visited.size < nodes.size)
    i += 1

    candidates = (nodes.keys - visited.keys)
    next_root = candidates[0]
    c = 0

    while ! nodes.include?(next_root)
      c += 1
      next_root = [c]
    end

    visited[next_root] = i
    queue = [next_root]

    #puts "------------------ INCREASING i to #{i}, next_root = #{next_root} (way_id = #{nodes[next_root].row['way_id']})"

    count = 0

    while(!queue.empty?)
      node = queue.pop()
      #puts "visiting #{nodes[node].inspect}"
      #puts nodes[node]
      nodes[node].neighs.each do |neigh|
        #puts "neigh #{neigh} visited - #{visited.has_key?(neigh)}"
        if ! visited.has_key?(neigh) and nodes.include?(neigh) then
           queue.push(neigh)
           visited[neigh] = i
           count += 1
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
