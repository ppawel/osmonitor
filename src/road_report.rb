#!/usr/bin/ruby

require 'net/http'
require 'erb'
require 'media_wiki'
require 'pg'

require './config'
require './model'
require './elogger'
require './wiki'



if ARGV.size == 0
  puts "Usage: road_report.rb <input page> <output page>"
  exit
elsif ARGV.size == 1
  @input_page = @output_page = ARGV[0]
else
  @input_page = ARGV[0]
  @output_page = ARGV[1]
end

TABLE_HEADER_MARKER = "<!-- OSMonitor HEADER -->"
TABLE_CELL_MARKER = "<!-- OSMonitor REPORT -->"
TIMESTAMP_BEGIN = "<!-- OSMonitor TIMESTAMP -->"
TIMESTAMP_END = "<!-- OSMonitor /TIMESTAMP -->"
STATS_BEGIN = "<!-- OSMonitor STATS -->"
STATS_END = "<!-- OSMonitor /STATS -->"
OK_COLOR = "PaleGreen"
ERROR_COLOR = "LightSalmon"
WARNING_COLOR = "PaleGoldenrod"

@mw = MediaWiki::Gateway.new('https://wiki.openstreetmap.org/w/api.php')

#@log = EnhancedLogger.new("osmonitor.log")
@log = EnhancedLogger.new(STDOUT)
@log.level = Logger::DEBUG

@status_template = ERB.new File.read("erb/road_status.erb")

@conn = PGconn.open( :host => $config['host'], :dbname => $config['dbname'], :user => $config['user'], :password => $config['password'] )

def render_issue_template(file, issue, status)
  return ERB.new(File.read("#{file}")).result(binding())
end

def tables_to_roads(page)
  roads = []

  page.tables.each do |table|
    if ! table.table_text.include?("{{PL")
      @log.debug "Table with no roads - next"
      next
    end

    table.rows.each do |row|
      m = row.row_text.scan(/PL\-(\w+)\|(\d+)/)

      if $1 and $2
        road = Road.new($1, $2, row)

        # Now let's try to parse input length for the road.
        length_text = row.cells[2].cell_text.strip.gsub('km', '').gsub(',', '.')
        road.input_length = length_text.to_f if !length_text.empty?
        roads << road
      end
    end
  end

  return roads
end

def fill_road_relation(road)
  sql_select = "SELECT *, OSM_GetRelationLength(r.id) AS length, OSM_IsMostlyCoveredBy(936128, r.id) AS covered
FROM relations r
WHERE
  r.tags -> 'type' = 'route' AND
  r.tags -> 'route' = 'road' AND"

  query = sql_select + eval($sql_where_by_road_type[road.ref_prefix], binding()) + " ORDER BY covered DESC, r.id"
  result = @conn.query(query).collect {|row| process_tags(row)}
  road.relation = result[0] if result.size > 0 and result[0]['covered'] == 't'
  road.other_relations = result[1..-1].select {|r| r['covered'] == 't'} if result.size > 1
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
  text.gsub!(/^\s*$/, '')
  text.gsub!("\n\n", "\n")
  return text
end

def insert_relation_id(status)
  return if ! status.road.relation

  new_row = status.road.row.row_text.dup
  new_row.gsub!(/\{\{relation\|\d*\}\}/im, "{{relation\|#{status.road.relation['id']}}}")
  status.road.row.update_text(new_row)
end

def remove_relation_id(status)
  new_row = status.road.row.row_text.dup.gsub(/\{\{relation\|\d*[\}]+/im, "{{relation|}}")
  status.road.row.update_text(new_row)
end

def insert_stats(page, report)
  stats_text = ERB.new(File.read("erb/road_report_stats.erb")).result(binding())
  page.page_text.gsub!(/#{Regexp.escape(STATS_BEGIN)}.*?#{Regexp.escape(STATS_END)}/mi,
    STATS_BEGIN + stats_text + STATS_END)
end

def fill_road_status(status)
  return if !status.road.row.row_text.include?(TABLE_CELL_MARKER)

  status.validate

  color = OK_COLOR
  color = WARNING_COLOR if status.get_issues(:WARNING).size > 0
  color = ERROR_COLOR if status.get_issues(:ERROR).size > 0

  status.road.row.set_background_color(color)

  if status.road.relation
    insert_relation_id(status)
  else
    remove_relation_id(status)
  end

  new_row = status.road.row.row_text.dup
  new_row.gsub!(/#{Regexp.escape(TABLE_CELL_MARKER)}.*/im, TABLE_CELL_MARKER + generate_status_text(status) + "\n")
  status.road.row.update_text(new_row)
end

def get_data_timestamp
  return @conn.query("SELECT OSM_GetDataTimestamp()").getvalue(0, 0)
end

def insert_data_timestamp(page)
  page.page_text.gsub!(/#{Regexp.escape(TIMESTAMP_BEGIN)}.*?#{Regexp.escape(TIMESTAMP_END)}/,
    TIMESTAMP_BEGIN + get_data_timestamp + TIMESTAMP_END)
end

def load_road_graph(road)
  result = @conn.query("
SELECT
  rm.member_role AS member_role,
  wn.way_id AS way_id,
--  w.tags AS way_tags,
  wn.node_id AS node_id
--  n.tags AS node_tags,
--  wn.sequence_id AS node_sequence_id
FROM way_nodes wn
INNER JOIN relation_members rm ON (rm.member_id = way_id AND rm.relation_id = #{road.relation['id']})
--INNER JOIN ways w ON (w.id = wn.way_id)
--INNER JOIN nodes n ON (n.id = wn.node_id)
ORDER BY rm.sequence_id, wn.way_id, wn.sequence_id
    ").collect do |row|
    # This simply translates "tags" columns to Ruby hashes.
    process_tags(row, 'way_tags')
    process_tags(row, 'node_tags')
  end

  road.graph.load(result)
end

def graph_to_ways(graph)
  graph.edges.collect {|e| e.source.get_mutual_way(e.target) if e.source}.uniq
end

def run_report
  page = get_wiki_page(@input_page)
  current_page_text = page.page_text.dup
  report = RoadReport.new

  #prepare_page(page)

  roads = tables_to_roads(page)

  @log.debug "Got #{roads.size} road(s)"

  roads.each_with_index do |road, i|
    road_before = Time.now
    @log.debug("BEGIN road #{road.ref_prefix + road.ref_number} (#{i + 1} of #{roads.size}) (input length = #{road.input_length})")

    status = RoadStatus.new(road)
    fill_road_relation(road)

    if road.relation
      @log.debug("  Found relation for road: #{road.relation['id']}")

      before = Time.now

      load_road_graph(road)

      @log.debug("  Loaded road graph (#{Time.now - before})")

      before = Time.now

      if !road.has_roles
        status.all_components = road.graph.all_graph.connected_components_nonrecursive
        status.all_url = create_overpass_url(road.all_ways)
      else
        status.backward_components = road.graph.backward_graph.connected_components_nonrecursive
        status.forward_components = road.graph.forward_graph.connected_components_nonrecursive
        status.backward_url = create_overpass_url(road.backward_ways)
        status.forward_url = create_overpass_url(road.forward_ways)
      end

      @log.debug("  Calculated status (#{Time.now - before})")
      #status.backward_fixes = road.graph.suggest_backward_fixes if status.backward.size > 1
      #status.forward_fixes = road.graph.suggest_forward_fixes if status.forward.size > 1
    end

    fill_road_status(status)
    report.add_status(status)

    @log.debug("END road #{road.ref_prefix + road.ref_number} took #{Time.now - road_before} " +
      "(all = #{status.all_components.size}, backward = #{status.backward_components.size}, forward = #{status.forward_components.size})")
  end

  insert_stats(page, report)

  # Check if anything has changed - no point in uploading the same page only with updated timestamp.
  if current_page_text == page.page_text
    puts 'No change in the report - not uploading new version to the wiki!'
    exit
  end

  insert_data_timestamp(page)
  wiki_login
  edit_wiki_page(@output_page, page.page_text)
end

def fill_ways(road, conn)
  sql_where = eval($sql_where_by_road_type[road.ref_prefix], binding())
  
  sql = "
SELECT distinct r.*
FROM ways r
WHERE #{sql_where} AND
(SELECT ST_Contains((SELECT hull FROM relation_boundaries WHERE relation_id = 936128), linestring)) = True"

  sql += " AND NOT EXISTS (SELECT * FROM relation_members WHERE member_id = r.id AND relation_id = #{road.relation['id']}) " if road.relation

  road.ways = conn.query(sql).collect { |row| process_tags(row) }
end

def process_tags(row, field_name = 'tags')
  row[field_name] = eval("{#{row[field_name]}}")
  return row
end

def get_wiki_page(name)
  return WikiPage.new(@mw.get name)
end

def edit_wiki_page(name, body)
  @mw.create(name, body, :overwrite => true, :summary => 'Automated')
end

def wiki_login
  @mw.login($config['wiki_username'], $config['wiki_password'])
end

run_report
