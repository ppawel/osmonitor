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

  def initialize(ref_prefix, ref_number, row)
    self.ref_prefix = ref_prefix
    self.ref_number = ref_number
    self.row = row
    self.other_relations = []
    self.relation_ways = []
    self.ways = []
    self.input_length = nil
    self.osm_length = nil
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
  attr_accessor :row
  attr_accessor :neighs

  def initialize(row)
    self.row = row
    self.neighs = []
  end
end
