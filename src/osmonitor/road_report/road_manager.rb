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

  def load_road(country, input)
    road = Road.new(country, input)

    log_time " ensure_road_row" do road.row = ensure_road_row(road) end
    log_time " update_road_relations_if_needed" do update_road_relations_if_needed(road, get_relation_sql(road)) end
    log_time " fill_road_relation" do fill_road_relation(road) end
    log_time " update_road_data_if_needed" do update_road_data_if_needed(road, get_ways_sql(road)) end

    data = []

    log_time " load_ways" do data = load_ways(road) end
    log_time " create_graph" do road.create_graph(data) end
    log_time " calculate_components" do road.calculate_components end

    log_time " calculate" do road.comps.each {|c| c.calculate} end
    log_time " find_super_components" do road.find_super_components end

    @@log.debug " comps = #{road.num_comps}, should be #{road.correct_num_comps}"

    road
  end

  def fill_road_relation(road)
    sql = "SELECT
    r.id AS id,
    r.tags AS tags,
    r.user_id AS last_update_user_id,
    u.name AS last_update_user_name,
    r.tstamp AS last_update_timestamp,
    r.changeset_id AS last_update_changeset_id
    FROM osmonitor_road_relations orr
    INNER JOIN relations r ON (r.id = orr.relation_id)
    INNER JOIN users u ON (u.id = r.user_id)
    WHERE orr.road_id = #{road.row['id']}
    ORDER BY r.id"

    result = @conn.query(sql).collect {|row| process_tags(row)}
    road.relation = Relation.new(result[0]) if result.size > 0

    if result.size > 1
      result[1..-1].each do |row|
        road.other_relations << Relation.new(row)
      end
    end
  end

  def load_ways(road)
    #puts sql
    result = get_road_data(road).collect do |row|
      # This simply translates "tags" columns to Ruby hashes.
      process_tags(row, 'way_tags')
      process_tags(row, 'node_tags')
    end

    #@log.debug("   load_road_graph: query took #{Time.now - before}")

    return result
  end

  def ensure_road_row(road)
    result = get_road_row(road)

    if result.nil?
      @conn.query("INSERT INTO osmonitor_roads (country, ref) VALUES ('#{road.country}', '#{road.ref}')")
      result = ensure_road_row(road)
    end

    result
  end

  def update_road_data_if_needed(road, data_sql)
    if road.row['data_sql_query'] != data_sql
      @@log.debug " Refreshing road data..."
      @conn.query("UPDATE osmonitor_roads SET data_sql_query = '#{PGconn.escape(data_sql)}' WHERE id = #{road.row['id']}")
      @conn.query("SELECT OSM_RefreshRoadData(#{road.row['id']})")
    end
  end

  def update_road_relations_if_needed(road, relation_sql)
    if road.row['relation_sql_query'] != relation_sql
      @@log.debug " Refreshing road relations..."
      @conn.query("UPDATE osmonitor_roads SET relation_sql_query = '#{PGconn.escape(relation_sql)}' WHERE id = #{road.row['id']}")
      @conn.query("SELECT OSM_RefreshRoadRelations(#{road.row['id']})")
    end
  end

  def get_road_row(road)
    result = @conn.query("SELECT *, '' AS status FROM osmonitor_roads
      WHERE country = '#{road.country}' AND ref = '#{road.ref}'").to_a
    return result[0] if !result.empty?
  end

  def get_road_data(road)
    @conn.query("SELECT *, ST_AsText(way_geom) AS way_geom,
    ST_AsText(node_geom) AS node_geom FROM osmonitor_road_data WHERE road_id = #{road.row['id']}
ORDER BY way_id, node_sequence_id, relation_sequence_id NULLS LAST, relation_id NULLS LAST")
  end

  def get_ways_sql(road)
    from_sql = ''

    if road.relation
      from_sql = "(#{get_sql_for_relation_ways(road)}) UNION (#{get_sql_for_ref_ways(road)})"
    else
      from_sql = "(#{get_sql_for_ref_ways(road)})"
    end

    sql = "SELECT DISTINCT ON (way_id, node_sequence_id)
    #{road.row['id']} AS road_id,
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
    node_id
  FROM (#{from_sql}) AS query
  ORDER BY way_id, node_sequence_id, relation_sequence_id NULLS LAST, relation_id NULLS LAST"
    sql
  end

  def get_relation_sql(road)
    "SELECT r.id
  FROM relations r
  WHERE
    #{get_find_relation_sql_where_clause(road)} AND
    OSM_IsMostlyCoveredBy('boundary_#{road.country}', r.id) = true
  ORDER BY r.id"
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
    w.linestring AS way_geom,
    n.geom AS node_geom,
    wn.node_id AS node_id
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
    w.linestring AS way_geom,
    n.geom AS node_geom,
    wn.node_id AS node_id
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

  def process_tags(row, field_name = 'tags')
    row[field_name] = eval("{#{row[field_name]}}")
    row
  end
end

end
end
