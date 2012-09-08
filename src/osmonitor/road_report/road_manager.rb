require 'config'

module OSMonitor
module RoadReport

class RoadManager
  include OSMonitorLogger

  attr_accessor :conn

  def initialize(conn)
    self.conn = conn
    self.conn.query('set enable_seqscan = false;') if conn
  end

  def load_road(country, ref_prefix, ref_number)
    return nil if !country or !ref_prefix or !ref_number

    road = Road.new(country, ref_prefix, ref_number)

    log_time " fill_road_relation" do fill_road_relation(road) end

    data = []

    log_time " load_ways" do data = load_ways(road) end
    log_time " create_graph" do road.create_graph(data) end
    log_time " calculate_components" do road.calculate_components end

    @@log.debug " comps = #{road.num_comps}, logical_comps = #{road.num_logical_comps}, should be #{road.correct_num_comps}"

    log_time " calculate" do road.comps.each {|c| c.calculate} end

    road
  end

  def process_tags(row, field_name = 'tags')
    row[field_name] = eval("{#{row[field_name]}}")
    return row
  end

  def fill_road_relation(road)
    sql = "
  SELECT
    r.id AS relation_id,
    r.tags AS relation_tags,
    r.user_id AS last_update_user_id,
    u.name AS last_update_user_name,
    r.tstamp AS last_update_timestamp,
    r.changeset_id AS last_update_changeset_id,
    OSM_IsMostlyCoveredBy('boundary_#{road.country}', r.id) AS covered
  FROM relations r
  LEFT JOIN users u ON (u.id = r.user_id)
  WHERE
    #{get_find_relation_sql_where_clause(road)}
  ORDER BY covered DESC, r.id"
puts sql
    result = @conn.query(sql).collect {|row| process_tags(row, 'relation_tags')}
    road.relation = create_relation(result[0]) if result.size > 0 and result[0]['covered'] == 't'

    if result.size > 1
      result[1..-1].each do |row|
        next if row['covered'] != 't'
        road.other_relations << create_relation(row)
      end
    end
  end

  def create_relation(row)
    relation = Relation.new(row['relation_id'].to_i, row['relation_tags'])
    relation.last_update = Changeset.new(row['last_update_user_id'].to_i, row['last_update_user_name'],
      row['last_update_timestamp'], row['last_update_changeset_id'])
    relation
  end

  def load_ways(road)
    from_sql = ''

    if road.relation
      from_sql = "(#{get_sql_for_relation_ways(road)}) UNION (#{get_sql_for_ref_ways(road)})"
    else
      from_sql = "(#{get_sql_for_ref_ways(road)})"
    end

    sql =
"SELECT DISTINCT ON (way_id, node_sequence_id)
    way_last_update_user_id,
    way_last_update_user_name,
    way_last_update_timestamp,
    way_last_update_changeset_id,
    relation_id,
    member_role,
    relation_sequence_id,
    node_sequence_id,
    way_id,
    way_tags,
    way_geom,
    node_geom,
    node_id,
    node_dist_to_next
  FROM (#{from_sql}) AS query
  ORDER BY way_id, node_sequence_id, relation_sequence_id NULLS LAST, relation_id NULLS LAST"
puts sql
    result = @conn.query(sql).collect do |row|
      # This simply translates "tags" columns to Ruby hashes.
      process_tags(row, 'way_tags')
      process_tags(row, 'node_tags')
    end

    #@log.debug("   load_road_graph: query took #{Time.now - before}")

    return result
  end

  def get_sql_for_relation_ways(road)
"SELECT
    way_user.id AS way_last_update_user_id,
    way_user.name AS way_last_update_user_name,
    w.tstamp AS way_last_update_timestamp,
    w.changeset_id AS way_last_update_changeset_id,
    rm.relation_id AS relation_id,
    rm.member_role AS member_role,
    rm.sequence_id AS relation_sequence_id,
    wn.sequence_id AS node_sequence_id,
    wn.way_id AS way_id,
    w.tags AS way_tags,
    ST_AsText(w.linestring) AS way_geom,
    ST_AsText(n.geom) AS node_geom,
    wn.node_id AS node_id,
    wn.dist_to_next AS node_dist_to_next
  FROM way_nodes wn
  INNER JOIN relation_members rm ON (rm.member_id = way_id)
  INNER JOIN nodes n ON (n.id = wn.node_id)
  INNER JOIN ways w ON (w.id = wn.way_id)
  LEFT JOIN users way_user ON (way_user.id = w.user_id)
  WHERE rm.relation_id = #{road.relation.id}"
  end

  def get_sql_for_ref_ways(road)
    # Need to cast because of http://archives.postgresql.org/pgsql-bugs/2010-12/msg00153.php
"SELECT
    way_user.id AS way_last_update_user_id,
    way_user.name AS way_last_update_user_name,
    w.tstamp AS way_last_update_timestamp,
    w.changeset_id AS way_last_update_changeset_id,
    NULL::bigint AS relation_id,
    NULL::text AS member_role,
    NULL::bigint AS relation_sequence_id,
    wn.sequence_id AS node_sequence_id,
    wn.way_id AS way_id,
    w.tags AS way_tags,
    ST_AsText(w.linestring) AS way_geom,
    ST_AsText(n.geom) AS node_geom,
    wn.node_id AS node_id,
    wn.dist_to_next AS node_dist_to_next
  FROM way_nodes wn
  INNER JOIN nodes n ON (n.id = wn.node_id)
  INNER JOIN ways w ON (w.id = wn.way_id)
  LEFT JOIN users way_user ON (way_user.id = w.user_id)
  WHERE
  #{get_find_ways_sql_where_clause(road)} AND
  #{get_sql_with_exceptions} AND
  ST_NumPoints(w.linestring) > 1 AND
  (SELECT ST_Contains(OSM_GetConfigGeomValue('boundary_#{road.country}'), w.linestring)) = True"
  end

  def get_find_relation_sql_where_clause(road)
    "r.tags -> 'type' = 'route' AND
    r.tags -> 'route' = 'road' AND
    #{eval(OSMonitor.config['road_report']['find_relation_sql_where_clause'][road.country][road.ref_prefix], binding())}"
  end

  def get_find_ways_sql_where_clause(road)
    eval(OSMonitor.config['road_report']['find_ways_sql_where_clause'][road.country][road.ref_prefix], binding())
  end

  def get_sql_with_exceptions
    "(NOT w.tags ?| ARRAY['aerialway', 'aeroway', 'building', 'waterway']) AND
    ((w.tags -> 'railway') IS NULL OR (w.tags -> 'highway') IS NOT NULL) AND
    ((w.tags -> 'highway') IS NULL OR w.tags -> 'highway' != 'cycleway')"
  end

  def get_node_xy(node_id)
    result = @conn.query("SELECT ST_X(geom), ST_Y(geom) FROM nodes WHERE id = #{node_id}")
    return result.getvalue(0, 0), result.getvalue(0, 1)
  end

  # Useful in tests and data_for_road.rb test script.
  def get_road_data(country, ref_prefix, ref_number)
    road = Road.new(country, ref_prefix, ref_number)
    fill_road_relation(road)
    return load_ways(road)
  end
end

end
end
