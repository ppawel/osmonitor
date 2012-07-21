#!/usr/bin/ruby

require 'net/http'
require 'erb'
require 'pg'
require './osm'
require './pg_db'
require './elogger'
require './wiki'

TABLE_HEADER_MARKER = "<!-- OSMonitor HEADER -->"
TABLE_CELL_MARKER = "<!-- OSMonitor REPORT -->"
ERROR_COLOR = "Salmon"
WARNING_COLOR = "PaleGoldenrod"

#@log = EnhancedLogger.new("osmonitor.log")
@log = EnhancedLogger.new(STDOUT)
@log.level = Logger::DEBUG

@status_template = ERB.new File.read("erb/road_status.erb")

@conn = PGconn.open( :host => "localhost", :dbname => 'osmdb', :user => "postgres" )

def tables_to_roads(page)
  roads = []

  page.tables.each do |table|
    if ! table.table_text.include?("{{PL")
      @log.debug "Table with no roads - next"
      next
    end

    table.rows.each do |row|
      road_ref = nil

      m = row.row_text.scan(/PL\-(\w+)\|(\d+)/)

      if $1 and $2
        road_ref = $1 + $2
        roads << Road.new(road_ref, row)
      end
    end
  end

  return roads
end

def get_road_relation(road)
  sql = {}

  sql["A"]=<<-EOF
SELECT *
FROM relations r
WHERE
  r.tags -> 'type' = 'route' AND
  r.tags -> 'route' = 'road' AND
  (not r.tags ? 'network' or r.tags -> 'network' != 'BAB') AND
  (r.tags -> 'ref' ilike '#{road.ref}' OR replace(r.tags -> 'ref', ' ', '') ilike '#{road.ref}')
    EOF

  sql["S"]=<<-EOF
SELECT *
FROM relations r
WHERE
  r.tags -> 'type' = 'route' AND
  r.tags -> 'route' = 'road' AND
  (not r.tags ? 'network' or r.tags -> 'network' != 'BAB') AND
  (r.tags -> 'ref' ilike '#{road.ref}' OR replace(r.tags -> 'ref', ' ', '') ilike '#{road.ref}')
    EOF

  sql["DK"]=<<-EOF
SELECT *
FROM relations r
WHERE
  r.tags -> 'type' = 'route' AND
  r.tags -> 'route' = 'road' AND
  ((r.tags -> 'ref' ilike '#{road.ref}' OR replace(r.tags -> 'ref', ' ', '') ilike '#{road.ref}') OR
    (r.tags -> 'name' ilike '%krajowa%' AND r.tags -> 'ref' = '#{road.get_number}'))
    EOF

  result = @conn.query(sql[road.get_type])

  return result.ntuples() > 0 ? result[0] : nil
end

def prepare_page(page)
  page.tables.each do |table|
    next if table.table_text.include?(TABLE_HEADER_MARKER)
    table.add_column_header(TABLE_HEADER_MARKER + "Bot report")
    table.add_cell(TABLE_CELL_MARKER)
  end
end

def generate_status_text(status)
  text = @status_template.result(binding)
  return text.gsub(/^\s*$/, '')
end

def insert_relation_id(status)
  return if ! status.road.relation

  new_row = status.road.row.row_text.dup
  new_row.gsub!(/{{relation\|\d*}}/im, "{{relation\|#{status.road.relation['id']}}}")
  status.road.row.update_text(new_row)
end

def fill_road_status(status)
  return if ! status.road.row.row_text.include?(TABLE_CELL_MARKER)

  color = nil

  if ! status.road.relation
    color = ERROR_COLOR
  elsif ! status.connected
    color = WARNING_COLOR
  end

  status.road.row.set_background_color(color) if color

  insert_relation_id(status)

  new_row = status.road.row.row_text.dup
  new_row.gsub!(/#{Regexp.escape(TABLE_CELL_MARKER)}.*/im, TABLE_CELL_MARKER + generate_status_text(status) + "\n")
  status.road.row.update_text(new_row)
end

def run_report
  page = get_wiki_page("User:Ppawel/RaportDrogiKrajowe")
  page_text = page.page_text.dup

  prepare_page(page)

  roads = tables_to_roads(page)
  
  @log.debug "Got #{roads.size} road(s)"

  roads.each_with_index do |road, i|
    road.relation = get_road_relation(road)

    @log.debug("Processing road #{road.ref} (#{i + 1} of #{roads.size})")

    if road.relation
      status = RoadStatus.new(road)
      components, visited = road_connected(road, @conn)
      @log.debug("components = #{components}")
      status.connected = components == 1
    else
      status = RoadStatus.new(road)
    end

    fill_road_status(status)
  end

  puts page.page_text
end

def road_connected(road, conn)
  return false if ! road.relation

  @nodes = {}
  before = Time.now

  conn.transaction do |dbconn|
    dbconn.query("
SELECT distinct wn.node_id AS id
FROM relation_members rm
INNER JOIN way_nodes wn ON (wn.way_id = rm.member_id AND rm.relation_id = #{road.relation['id']})
--INNER JOIN nodes n ON (n.id = wn.node_id)
      ").each do |row|
      row["tags"] = "'a'=>2"
      @nodes[row["id"].to_i] = OSM::Node[[0,0], row]
    end

    dbconn.query("SELECT DISTINCT node_id, ARRAY(SELECT DISTINCT
                --wn.node_id,
                wn_neigh.node_id
                --wn.way_id
        FROM  way_nodes wn_neigh
        WHERE wn_neigh.way_id = wn.way_id AND (wn_neigh.sequence_id = wn.sequence_id - 1 OR wn_neigh.sequence_id = wn.sequence_id + 1)
        ) AS neighs
FROM way_nodes wn
INNER JOIN relation_members rm ON (rm.member_id = way_id AND rm.relation_id = #{road.relation['id']})
    ").each do |row|
      row['neighs'].gsub!('{','[')
      row['neighs'].gsub!('}',']')
      @nodes[row["node_id"].to_i].neighs += eval(row['neighs']).collect {|x| x.to_i}
    end
  end

  @log.debug "query took #{Time.now - before}"

  before = Time.now
  *a = bfs(@nodes)
  @log.debug "bfs took #{Time.now - before} (#{@nodes.size})"

  return a
end

def bfs(nodes, start_node = nil)
  return {} if nodes.empty?
  visited = {}
  i = 0

  #puts nodes

  while (visited.size < nodes.size)
    #puts "#{visited.size} <? #{nodes.size}"
    i += 1

    before = Time.now

    if i == 1 and start_node
      next_root = start_node
    else
      candidates = (nodes.keys - visited.keys)
      next_root = candidates[0]
      c = 0

      while ! nodes.include?(next_root)
        c += 1
        next_root = [c]
      end
    end

    #@log.debug("candidate choice took #{Time.now - before}")

    visited[next_root] = i
    queue = [next_root]
    
    #puts "------------------ INCREASING i to #{i}, next_root = #{next_root}"
    
    count = 0

    while(!queue.empty?)
      node = queue.pop()
      #puts "visiting #{node}"
      #puts nodes[node]
      nodes[node].neighs.each do |neigh|
        #puts "neigh #{neigh} visited - #{visited.has_key?(neigh)}"
        if ! visited.has_key?(neigh) and nodes.include?(neigh) then
           queue.push(neigh)
           visited[neigh] = i
           count += 1
         end
      end
    end
  end

  return i, visited
end

run_report
