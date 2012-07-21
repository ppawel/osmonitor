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

#@log = EnhancedLogger.new("osmonitor.log")
@log = EnhancedLogger.new(STDOUT)
@log.level = Logger::DEBUG

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

def run_report
  @report = []
  page = get_wiki_page("User:Ppawel/RaportTest")
  page_text = page.page_text.dup

  prepare_page(page)

  roads = tables_to_roads(page)
  
  @log.debug "Got #{roads.size} road(s)"

  roads.each_with_index do |road, i|
    road.relation = get_road_relation(road)

    @log.debug("Processing road #{road.ref} (#{i + 1} of #{roads.size})")
    
    if road.relation
      status = RoadStatus.new(road)
      components, visited = road_connected(road.relation["id"], @conn)
    else
      status = RoadStatus.new(road)
    end

    @report << status

    @log.debug "Status: #{status.inspect}"
  end

  template = ERB.new File.read("erb/poland_roads.erb")
  puts template.result
end

  def road_connected(relation_id, conn)
    return false if ! relation_id

    @nodes = {}

    conn.transaction do |dbconn|
      dbconn.query("
SELECT distinct wn.node_id AS id
FROM relation_members rm
INNER JOIN way_nodes wn ON (wn.way_id = rm.member_id AND rm.relation_id = #{relation_id})
--INNER JOIN nodes n ON (n.id = wn.node_id)
      ").each do |row|
        row["tags"] = "'a'=>2"
        @nodes[row["id"].to_i] = OSM::Node[[0,0], row]
      
      end

      dbconn.query("
SELECT DISTINCT n.*
FROM relation_members rm
INNER JOIN way_nodes wn ON (wn.way_id = rm.member_id AND rm.relation_id = #{relation_id})
INNER JOIN node_neighs n ON (n.node_id = wn.node_id)
ORDER BY n.node_id
      ").each do |row|
        @nodes[row["node_id"].to_i].neighs << row["neigh_id"].to_i
      end
    end

    return bfs(@nodes)
  end
  
  def bfs(nodes, start_node = nil)
    return {} if nodes.empty?
    visited = {}
    i = 0

    #puts nodes

    while (visited.size < nodes.size)
      #puts "#{visited.size} <? #{nodes.size}"
      i += 1

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
      
      visited[next_root] = i
      queue = [next_root]
      
      #puts "------------------ INCREASING i to #{i}, next_root = #{next_root}"
    

    while(!queue.empty?)
      node = queue.pop()
      #puts "visiting #{node}"
      #puts nodes[node]
      nodes[node].neighs.each do |neigh|
        #puts "neigh #{neigh} visited - #{visited.has_key?(neigh)}"
        if ! visited.has_key?(neigh) and nodes.include?(neigh) then
           queue.push(neigh)
           visited[neigh] = i
         end
      end
    end
    
    end

    return i, visited
  end

  def name_to_nr_krajowy(name)
    return name.scan(/(\d+)/)[0][0].to_i
  end

run_report
