# encoding: utf-8

require 'config'
require 'unicode_utils'

module OSMonitor
module AdminReport

class AdminManager
  include OSMonitorLogger

  attr_accessor :conn

  def initialize(conn)
    self.conn = conn
    self.conn.query('set enable_seqscan = false;') if conn
  end

  def load_boundary(country, input)
    boundary = Boundary.new(country, input)

    load_relations(boundary)
    load_ways(boundary) if boundary.relation

    boundary
  end

  def load_relations(boundary)
    sql = "SELECT
    r.id AS id,
    r.tags AS tags,
    r.user_id AS last_update_user_id,
    u.name AS last_update_user_name,
    r.tstamp AS last_update_timestamp,
    r.changeset_id AS last_update_changeset_id
    FROM relations r
    INNER JOIN users u ON (u.id = r.user_id)
    WHERE #{eval(OSMonitor.config['admin_report']['find_relation_sql_where_clause']['PL'][boundary.input['admin_level']])}
    ORDER BY r.id"
#puts sql
    result = @conn.query(sql).collect {|row| process_tags(row)}
    boundary.relation = Relation.new(result[0]) if result.size > 0
  end

  def load_ways(boundary)
    sql = "SELECT
      ST_IsClosed(ST_LineMerge(ST_Collect(w.linestring)))
    FROM ways w
    INNER JOIN relation_members rm ON (rm.member_id = w.id)
    WHERE rm.relation_id = #{boundary.relation.id}"

    boundary.closed = @conn.query(sql).getvalue(0, 0) == 't'
  end

  def process_tags(row, field_name = 'tags')
    row[field_name] = eval("{#{row[field_name]}}")
    row
  end
end

end
end
