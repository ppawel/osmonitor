require 'config'

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

    sql = "SELECT
    r.id AS id,
    r.tags AS tags,
    r.user_id AS last_update_user_id,
    u.name AS last_update_user_name,
    r.tstamp AS last_update_timestamp,
    r.changeset_id AS last_update_changeset_id
    FROM relations r
    INNER JOIN users u ON (u.id = r.user_id)
    WHERE r.tags->'admin_level' = '#{boundary.input['admin_level']}'
      AND r.tags->'name' ilike '%#{boundary.input['name']}%'
    ORDER BY r.id"

    result = @conn.query(sql).collect {|row| process_tags(row)}
    boundary.relation = Relation.new(result[0]) if result.size > 0

    boundary
  end

  def process_tags(row, field_name = 'tags')
    row[field_name] = eval("{#{row[field_name]}}")
    row
  end
end

end
end
