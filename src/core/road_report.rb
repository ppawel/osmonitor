class RoadInput
  attr_accessor :row
  attr_accessor :length
  attr_accessor :ref_prefix
  attr_accessor :ref_number

  def initialize(wiki_table_row)
    @row = wiki_table_row
    m = row.row_text.scan(/PL\-(\w+)\|(\d+)/)

    if $1 and $2
      @ref_prefix = $1
      @ref_number = $2

      # Now let's try to parse input length for the road.
      length_text = row.cells[2].cell_text.strip.gsub('km', '').gsub(',', '.')
      @length = length_text.to_f if !length_text.empty?
    end
  end
end

class RoadStatus
  attr_accessor :road
  attr_accessor :input
  attr_accessor :issues
  attr_accessor :all_components
  attr_accessor :backward_components
  attr_accessor :forward_components
  attr_accessor :ref_components
  attr_accessor :backward_fixes
  attr_accessor :forward_fixes
  attr_accessor :all_url
  attr_accessor :backward_url
  attr_accessor :forward_url

  def initialize(road_input, road)
    self.road = road
    self.input = road_input
    self.issues = []
    self.all_components = []
    self.backward_components = []
    self.forward_components = []
    self.ref_components = []
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
    road.relation_num_comps == 1
  end

  def too_many_end_nodes
    road.relation_comps.collect {|comp| comp.end_nodes if comp.end_nodes.size > 4}.select {|x| x}
  end

  def too_few_end_nodes
    road.relation_comps.collect {|comp| comp.end_nodes if comp.end_nodes.size < 2}.select {|x| x}
  end

  def graph_to_ways(graph)
    graph.edges.collect {|e| e.source.get_mutual_way(e.target) if e.source}.uniq
  end

  def validate
    add_warning('no_relation') if !road.relation
    add_error('has_many_covered_relations') if road.relation and has_many_covered_relations

    if !ways_without_highway_tag.empty?
      add_error('has_ways_without_highway_tag', {:ways => ways_without_highway_tag})
    end

    if !too_many_end_nodes.empty? or !too_few_end_nodes.empty?
      add_warning('end_nodes', {:too_many => too_many_end_nodes, :too_few => too_few_end_nodes})
    end

    if road.relation
      if road.length
        add_info('osm_length')
        add_warning('wrong_length') if input.length and !has_proper_length
      end

      add_info('way_stats')
      add_warning('wrong_network') if !has_proper_network
      add_error('relation_disconnected') if !connected?
      add_error('not_navigable') if !road.relation_comps[0].has_complete_paths?
    end
=begin
    #if !road.ways_with_wrong_ref.empty?
    #  add_error('ways_with_wrong_ref', {:ways => road.ways_with_wrong_ref})
    #end

    #add_warning('ways_not_in_relation', {:ways => road.ways}) if road.ways.size > 0
=end
  end

  def green?
    return (get_issues(:ERROR).empty? and get_issues(:WARNING).empty?)
  end

  def length_diff
    return (road.length - input.length).abs.to_i
  end

  def has_proper_length
    return nil if !road.relation or !road.length or !input.length
    return length_diff < 2
  end

  def get_network
    road.relation["tags"]["network"] if road.relation["tags"]["network"]
  end

  def get_proper_network
    return get_relation_network(road.ref_prefix)
  end

  def has_proper_network
    return get_network == get_proper_network 
  end

  def has_many_relations
    return !road.other_relations.empty?
  end

  def has_many_covered_relations
    return  road.other_relations.select {|x| x['covered'] == 't'}.size > 0
  end

  def percent_with_lanes
    return ((road.ways.values.select { |way| way.tags.has_key?('lanes') }.size / road.ways.size.to_f) * 100).to_i
  end

  def percent_with_maxspeed
    return ((road.ways.values.select { |way| way.tags.has_key?('maxspeed') }.size / road.ways.size.to_f) * 100).to_i
  end

  # Finds ways without "highway" tag (exception is ferry ways, see http://www.openstreetmap.org/browse/way/23541424).
  def ways_without_highway_tag
    return road.ways.values.select { |way| !way.tags.has_key?('highway') and (!way.tags.has_key?('route') or way.tags['route'] != 'ferry') }
  end

  # Finds ways without "ref" tag or with wrong tag value.
  def ways_with_wrong_ref
    return road.ways.values.select {|way| !way.tags.has_key?('ref') or !road.get_refs(way).include?(eval($road_type_ref_tag[road.ref_prefix], binding()))}
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
    total_input_length = statuses.reduce(0) {|total, status| status.input.length.nil? ? total : (total + status.input.length)}
    green_length = statuses.inject(0) {|total, status| status.green? ? total + status.road.length : total}
    green_length_percent = 0
    green_length_percent = green_length / total_input_length * 100 if total_input_length > 0
    return total_input_length, green_length, green_length_percent
  end
end
