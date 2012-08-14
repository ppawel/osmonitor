#!/usr/bin/ruby

$:.unshift File.dirname(__FILE__)

require 'elogger'
require 'core'

require 'net/http'
require 'erb'
require 'media_wiki'
require 'pg'

require 'config'
require 'road_manager'
require 'wiki'

module OSMonitor

include OSMonitorLogger

TABLE_HEADER_MARKER = "<!-- OSMonitor HEADER -->"
TIMESTAMP_BEGIN = "<!-- OSMonitor TIMESTAMP -->"
TIMESTAMP_END = "<!-- OSMonitor /TIMESTAMP -->"
STATS_BEGIN = "<!-- OSMonitor STATS -->"
STATS_END = "<!-- OSMonitor /STATS -->"
OK_COLOR = "PaleGreen"
ERROR_COLOR = "LightSalmon"
WARNING_COLOR = "PaleGoldenrod"

@info_template = ERB.new File.read("erb/road_info.erb")
@status_template = ERB.new File.read("erb/road_status.erb")

def self.render_issue_template(file, issue, status)
  return ERB.new(File.read("#{file}")).result(binding())
end

def self.read_road_input(page)
  input = []

  page.tables.each do |table|
    if !table.table_text.include?("{{PL")
      @@log.debug "Table with no roads - next"
      next
    end

    input += table.rows.collect do |row|
      input = RoadInput.new
      input.from_wiki_table_row(row)
      input
    end
  end

  return input
end

def self.prepare_page(page)
  page.tables.each do |table|
    next if table.table_text.include?(TABLE_HEADER_MARKER)
    table.add_column_header(TABLE_HEADER_MARKER + "Bot report")
    table.add_cell(TABLE_CELL_MARKER)
  end
end

def self.generate_template_text(template, status)
  text = template.result(binding)
  text.gsub!(/^\s*$/, '')
  #text.gsub!(/\n$/, '')
  text.gsub!("\n\n", "\n")
  #text.gsub!(/^\n/, "")
  return text
end

def self.insert_stats(page, report)
  stats_text = ERB.new(File.read("erb/road_report_stats.erb")).result(binding())
  page.page_text.gsub!(/#{Regexp.escape(STATS_BEGIN)}.*?#{Regexp.escape(STATS_END)}/mi,
    STATS_BEGIN + stats_text + STATS_END)
end

def self.fill_road_status(status)
  #return if !status.input.row.row_text.include?(TABLE_CELL_MARKER)

  status.validate

  color = OK_COLOR
  color = WARNING_COLOR if status.get_issues(:WARNING).size > 0
  color = ERROR_COLOR if status.get_issues(:ERROR).size > 0

  status.input.row.set_background_color(color)

  status.input.row.cells[1].update_text(generate_template_text(@info_template, status))
  status.input.row.cells[4].update_text(generate_template_text(@status_template, status))
  status.input.row.update_text(status.input.row.row_text.gsub("\n\n", "\n"))
end

def self.get_data_timestamp(conn)
  return conn.query("SELECT OSM_GetDataTimestamp()").getvalue(0, 0)
end

def self.insert_data_timestamp(page, conn)
  timestamp = get_data_timestamp(conn)
  page.page_text.gsub!(/#{Regexp.escape(TIMESTAMP_BEGIN)}.*?#{Regexp.escape(TIMESTAMP_END)}/,
    TIMESTAMP_BEGIN + timestamp + TIMESTAMP_END)
  timestamp
end

def self.run_report(input_page, output_page)
  report_start = Time.now
  conn = PGconn.open( :host => $config['host'], :dbname => $config['dbname'], :user => $config['user'], :password => $config['password'] )
  mw = MediaWiki::Gateway.new('https://wiki.openstreetmap.org/w/api.php')
  page = WikiPage.new(mw.get input_page)
  road_manager = RoadManager.new(conn)
  current_page_text = page.page_text.dup
  report = RoadReport.new
  inputs = read_road_input(page)

  @@log.debug "Got #{inputs.size} road(s) to process"

  inputs.each_with_index do |input, i|
    road_before = Time.now
    @@log.debug("BEGIN road #{input.ref_prefix + input.ref_number} (#{i + 1} of #{inputs.size}) (input length = #{input.length.inspect})")

    road = road_manager.load_road(input.ref_prefix, input.ref_number)
    status = RoadStatus.new(input, road)

    fill_road_status(status)
    report.add_status(status)

    @@log.debug("END road #{road.ref_prefix + road.ref_number} took #{Time.now - road_before} " +
      "(comps = #{status.road.comps.map {|c| c.graph.num_vertices}.inspect})")
  end

  insert_stats(page, report)

  puts "Page size (current = #{current_page_text.size}, old = #{page.page_text.size})"

  # Check if anything has changed - no point in uploading the same page only with updated timestamp.
  if current_page_text == page.page_text
    puts 'No change in the report - not uploading new version to the wiki!'
    exit
  end

  timestamp = insert_data_timestamp(page, conn)

  puts "Uploading to the wiki... (data timestamp = #{timestamp})"

  mw.login($config['wiki_username'], $config['wiki_password'])
  mw.create(output_page, page.page_text, :overwrite => true, :summary => 'Automated')

  puts "Done (took #{Time.now - report_start} seconds)."
end

end

if ARGV.size == 0
  puts "Usage: road_report.rb <input page> <output page>"
  exit
elsif ARGV.size == 1
  input_page = output_page = ARGV[0]
else
  input_page = ARGV[0]
  output_page = ARGV[1]
end

OSMonitor.run_report(input_page, output_page)
