module OSMonitor
module RoadReport

class RoadStatus < OSMonitor::Status
  def validate
    if @entity.relation and !@entity.relation.tags['osmonitor:noreport'].nil?
      @noreport = true
      add_info('noreport')
      return
    end

    if input_length
      add_info('osm_length')
    else
      # No input length = warning.
      add_warning('osm_length')
    end

    add_info('last_update')

    add_error('no_relation') if !@entity.relation
    add_error('has_many_covered_relations') if @entity.relation and has_many_covered_relations

    if !ways_without_highway_tag.empty?
      add_error('has_ways_without_highway_tag', {:ways => ways_without_highway_tag})
    end

    if @entity.empty?
      add_error('empty')
    else
      if !connected?
        add_error('road_disconnected')
      else
        add_error('no_beginning_and_end') if !found_beginning_and_end?
        add_warning('wrong_length') if @entity.length and input_length and !has_proper_length
        add_error('not_navigable') if found_beginning_and_end? and @entity.length.nil?#@entity.has_incomplete_paths?
      end
    end

    add_warning('wrong_network') if @entity.relation and !has_proper_network
  end

  def connected?
    @entity.num_comps == @entity.correct_num_comps
  end

  def too_many_end_nodes
    @entity.comps.collect {|comp| comp.end_nodes if comp.end_nodes.size > 4}.select {|x| x}
  end

  def too_few_end_nodes
    @entity.comps.collect {|comp| comp.end_nodes if comp.end_nodes.size < 2}.select {|x| x}
  end

  def input_length
    return @entity.relation.distance if @entity.relation and @entity.relation.distance
    return @entity.input['distance'].to_f if @entity.input.has_key?('distance')
  end

  def found_beginning_and_end?
    @entity.comps.detect {|comp| !comp.found_beginning_and_end?}.nil?
  end

  def length_diff
    return (@entity.length - input_length).abs.to_i
  end

  def has_proper_length
    return nil if !@entity.length or !input_length
    return length_diff < 2
  end

  def get_network
    @entity.relation.tags['network'] if @entity.relation.tags['network']
  end

  def get_proper_network
    OSMonitor.config['road_report']['road_type_network_tag'][@entity.country][@entity.ref_prefix]
  end

  def has_proper_network
    get_proper_network.nil? or (get_network == get_proper_network)
  end

  def has_many_relations
    return !@entity.other_relations.empty?
  end

  def has_many_covered_relations
    !@entity.other_relations.empty?
  end

  def percent_with_lanes
    return (@entity.ways.values.select { |way| way.tags.has_key?('lanes') }.size / @entity.ways.size.to_f) * 100
  end

  def percent_with_maxspeed
    return (@entity.ways.values.select { |way| way.tags.has_key?('maxspeed') }.size / @entity.ways.size.to_f) * 100
  end

  # Finds ways without "highway" tag (exception is ferry ways, see http://www.openstreetmap.org/browse/way/23541424).
  def ways_without_highway_tag
    return @entity.ways.values.select { |way| !way.tags.has_key?('highway') and (!way.tags.has_key?('route') or way.tags['route'] != 'ferry') }
  end

  # Finds ways without "ref" tag or with wrong tag value.
  def ways_with_wrong_ref
    return @entity.ways.values.select {|way| !way.tags.has_key?('ref') or
      !@entity.get_refs(way).include?(eval(OSMonitor.config['road_report']['road_type_ref_tag'][@entity.country][@entity.ref_prefix], binding()))}
  end
end

class RoadReport < OSMonitor::Report
  # Returns percent_green, percent_yellow, percent_red.
  def get_percentages
    return 0, 0, 0 if statuses.size == 0
    green = statuses.select {|status| status.green?}.size
    yellow = statuses.select {|status| status.get_issues(:WARNING).size > 0 and status.get_issues(:ERROR).size == 0}.size
    red = statuses.select {|status| status.get_issues(:ERROR).size > 0}.size
    return (green / statuses.size.to_f * 100).to_i, (yellow / statuses.size.to_f * 100).to_i, (red / statuses.size.to_f * 100).to_i
  end

  # Returns length statistics (in km): total_input_length, green_length, green_length_percent.
  def get_length_stats
    total_input_length = statuses.reduce(0) {|total, status| status.input_length.nil? ? total : (total + status.input_length)}
    green_length = statuses.inject(0) {|total, status| status.green? ? total + status.entity.length : total}
    green_length_percent = 0
    green_length_percent = green_length / total_input_length * 100 if total_input_length > 0
    return total_input_length, green_length, green_length_percent
  end
end

end
end
