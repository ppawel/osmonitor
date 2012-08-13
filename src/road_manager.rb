require 'config'

module OSMonitor

class RoadManager
  include OSMonitorLogger

  attr_accessor :conn

  def initialize(conn)
    self.conn = conn
    self.conn.query('set enable_seqscan = false;') if conn
  end

  def load_road(ref_prefix, ref_number)
    road = Road.new(ref_prefix, ref_number)

    log_time " fill_road_relation" do
      fill_road_relation(road)
    end

    data = []

    log_time " load_ways" do data = load_ways(road) end
    log_time " create_graph" do road.create_graph(data) end
    log_time " calculate_paths" do road.comps.each {|c| c.calculate_paths} if road.num_comps == 1 end

    #log_time " load_node_xy" do
    #  road.comps.each {|c| c.end_nodes.each {|node| node.x, node.y = get_node_xy(node.id)}}
    #  road.comps.each {|c| c.paths.each {|p| p.from.x, p.from.y = get_node_xy(p.from.id)}}
    #  road.comps.each {|c| c.paths.each {|p| p.to.x, p.to.y = get_node_xy(p.to.id)}}
    #end

    #data = load_ref_ways(road)
    #road.create_ref_graph(data)

    return road
  end

  def process_tags(row, field_name = 'tags')
    row[field_name] = eval("{#{row[field_name]}}")
    return row
  end

  def fill_road_relation(road)
    sql_select = "SELECT *, OSM_IsMostlyCoveredBy('boundary_PL', r.id) AS covered
  FROM relations r
  WHERE
    r.tags -> 'type' = 'route' AND
    r.tags -> 'route' = 'road' AND"

    query = sql_select + eval($sql_where_by_road_type_relations[road.ref_prefix], binding()) + " ORDER BY covered DESC, r.id"
    result = @conn.query(query).collect {|row| process_tags(row)}
    road.relation = result[0] if result.size > 0 and result[0]['covered'] == 't'
    road.other_relations = result[1..-1].select {|r| r['covered'] == 't'} if result.size > 1
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
#puts sql
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
    rm.relation_id AS relation_id,
    rm.member_role AS member_role,
    rm.sequence_id AS relation_sequence_id,
    wn.sequence_id AS node_sequence_id,
    wn.way_id AS way_id,
    w.tags AS way_tags,
    ST_AsText(w.linestring) AS way_geom,
    ST_AsText(wn.node_geom) AS node_geom,
    wn.node_id AS node_id,
    wn.dist_to_next AS node_dist_to_next
  FROM way_nodes wn
  INNER JOIN relation_members rm ON (rm.member_id = way_id)
  INNER JOIN ways w ON (w.id = wn.way_id)
  WHERE rm.relation_id = #{road.relation['id']}"
  end

  def get_sql_for_ref_ways(road)
    # Need to cast because of http://archives.postgresql.org/pgsql-bugs/2010-12/msg00153.php
"SELECT
    NULL::bigint AS relation_id,
    NULL::text AS member_role,
    NULL::bigint AS relation_sequence_id,
    wn.sequence_id AS node_sequence_id,
    wn.way_id AS way_id,
    w.tags AS way_tags,
    ST_AsText(w.linestring) AS way_geom,
    ST_AsText(wn.node_geom) AS node_geom,
    wn.node_id AS node_id,
    wn.dist_to_next AS node_dist_to_next
  FROM way_nodes wn
  INNER JOIN ways w ON (w.id = wn.way_id)
  WHERE #{eval($sql_where_by_road_type_ways[road.ref_prefix], binding())} AND
  (NOT w.tags ?| ARRAY['aerialway', 'aeroway', 'building', 'construction', 'railway']) AND
  (SELECT ST_Contains(OSM_GetConfigGeomValue('boundary_PL'), w.linestring)) = True"
  end

  def get_node_xy(node_id)
    result = @conn.query("SELECT ST_X(geom), ST_Y(geom) FROM nodes WHERE id = #{node_id}")
    return result.getvalue(0, 0), result.getvalue(0, 1)
  end

  # Useful in tests and data_for_road.rb test script.
  def get_road_data(ref_prefix, ref_number)
    road = Road.new(ref_prefix, ref_number)
    fill_road_relation(road)
    return load_ways(road)
  end
end

end
