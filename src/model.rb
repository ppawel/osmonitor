require 'config'
require 'wiki'
require 'road_graph'

def get_relation_network(prefix)
  return $road_type_network_tag[prefix]
end

def create_overpass_url(ways)
  s = ''
  ways.each {|w| s += "way(#{w.id});"}
  "http://www.overpass-api.de/api/convert?data=(#{s});(._;node(w));out;&target=openlayers"
end

class Road
  attr_accessor :ref_prefix
  attr_accessor :ref_number
  attr_accessor :relation
  attr_accessor :other_relations
  attr_accessor :relation_ways
  attr_accessor :ways
  attr_accessor :input_length
  attr_accessor :nodes
  attr_accessor :graph
  attr_accessor :has_roles
  attr_accessor :row

  def initialize(ref_prefix, ref_number)
    self.ref_prefix = ref_prefix
    self.ref_number = ref_number
    self.ways = {}
    self.nodes = {}
    self.other_relations = []
    self.relation_ways = []
    self.input_length = nil
    self.graph = RoadGraph.new(self)
    self.has_roles = false
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
end

class RoadStatus
  attr_accessor :road
  attr_accessor :issues
  attr_accessor :all_components
  attr_accessor :backward_components
  attr_accessor :forward_components
  attr_accessor :backward_fixes
  attr_accessor :forward_fixes
  attr_accessor :all_url
  attr_accessor :backward_url
  attr_accessor :forward_url

  def initialize(road)
    self.road = road
    self.issues = []
    self.all_components = []
    self.backward_components = []
    self.forward_components = []
    self.backward_fixes = []
    self.forward_fixes = []
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

  def connected?
    if !@road.has_roles
      @all_components.size == 1
    else
      @backward_components.size == 1 and @forward_components.size == 1
    end
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

    add_warning('relation_disconnected') if !connected?
    add_warning('wrong_network') if !road.has_proper_network
    add_warning('wrong_length') if !road.has_proper_length.nil? and !road.has_proper_length
    add_info('osm_length', road.get_osm_length)
    add_info('percent_with_lanes', road.percent_with_lanes)
    add_info('percent_with_maxspeed', road.percent_with_maxspeed)
  end

  def green?
    return (get_issues(:ERROR).empty? and get_issues(:WARNING).empty?)
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

  # Returns length statistics (in km): total_input_length, green_length, green_length_percent.
  def get_length_stats
    total_input_length = statuses.reduce(0) {|total, status| status.road.input_length.nil? ? total : (total + status.road.input_length)}
    green_length = statuses.inject(0) {|total, status| status.green? ? total + status.road.get_osm_length : total}
    green_length_percent = 0
    green_length_percent = green_length / total_input_length * 100 if total_input_length > 0
    return total_input_length, green_length, green_length_percent
  end
end

# Represents a node in OSM sense.
class Node
  attr_accessor :id
  attr_accessor :tags
  attr_accessor :ways

  def initialize(id, tags)
    self.id = id
    self.tags = tags
    self.ways = {}
  end

  def add_way(way)
    @ways[way.id] = way
  end

  def get_mutual_way(node)
    common_way_ids = node.ways.keys & @ways.keys
    return @ways[common_way_ids[0]] if !common_way_ids.empty?
  end

  def hash
    return id
  end

  def ==(o)
    o.class == self.class and o.id == id
  end
  alias_method :eql?, :==

  def to_s
    return "Node(#{id})"
  end
end

def member_role_all?(role)
  ['', 'member', 'route'].include?(role)
end

def member_role_backward?(role)
  member_role_all?(role) or ['backward'].include?(role)
end

def member_role_forward?(role)
  member_role_all?(role) or ['forward'].include?(role)
end

# Represents a way in OSM sense.
class Way
  attr_accessor :id
  attr_accessor :member_role
  attr_accessor :tags
  attr_accessor :geom

  def initialize(id, member_role, tags)
    self.id = id
    self.member_role = member_role
    self.tags = tags
  end

  def all?
    member_role_all?(@member_role)
  end

  def backward?
    member_role_backward?(@member_role)
  end

  def forward?
    member_role_forward?(@member_role)
  end

  def hash
    return id
  end

  def ==(o)
    o.class == self.class and o.id == id
  end
  alias_method :eql?, :==
end
