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

    data = []

    log_time " load_road_data" do data = load_road_data(road) end
    log_time " load_relations" do load_relations(road) end
    log_time " create_graph" do road.create_graph(data) end
    log_time " calculate_components" do road.calculate_components end

    log_time " calculate" do road.comps.each {|c| c.calculate} end
    log_time " find_super_components" do road.find_super_components end

    @@log.debug " comps = #{road.num_comps}, should be #{road.correct_num_comps}"

    road
  end

  def load_relations(road)
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
    WHERE orr.road_id = '#{road.row['id']}'
    ORDER BY r.id"

    result = @conn.query(sql).collect {|row| process_tags(row)}
    road.relation = Relation.new(result[0]) if result.size > 0
    result[1..-1].each {|row| road.other_relations << Relation.new(row)} if result.size > 1
  end

  def load_road_data(road)
    result = []
    @conn.query("SELECT * FROM OSM_LoadRoadData('#{road.row['id']}')").each do |row|
      process_tags(row, 'way_tags')
      process_tags(row, 'node_tags')
      row['node_wkb'] = PGconn.unescape_bytea(row['node_wkb'])
      row['way_wkb'] = PGconn.unescape_bytea(row['way_wkb'])
      result << row
    end
    result
  end

  def ensure_road_row(road)
    result = get_road_row(road)

    if result.nil?
      @@log.debug '  No road row, creating new one...'
      @conn.query("INSERT INTO osmonitor_roads (id, country, ref) VALUES ('#{road.input['id']}', '#{road.country}', '#{road.ref}')")
      result = ensure_road_row(road)
    end

    result
  end

  def get_road_row(road)
    result = @conn.query("SELECT *, '' AS status FROM osmonitor_roads WHERE country = '#{road.country}' AND ref = '#{road.ref}'").to_a
    return result[0] if !result.empty?
  end

  # This simply translates "tags" columns to Ruby hashes.
  def process_tags(row, field_name = 'tags')
    row[field_name] = eval("{#{row[field_name]}}")
    row
  end
end

end
end
