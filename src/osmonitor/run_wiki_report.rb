$:.unshift File.absolute_path(File.dirname(__FILE__) + '/../')
$:.unshift File.absolute_path(File.dirname(__FILE__) + '/../../')

$osmonitor_home_dir = File.absolute_path(File.dirname(__FILE__) + '/../../')

require 'osmonitor'
require 'csv'
require 'erb'

module OSMonitor

include OSMonitorLogger

def self.get_data_timestamp(conn)
  conn.query("SELECT OSM_GetDataTimestamp()").getvalue(0, 0)
end

def self.run_wiki_reports(input_page, output_page)
  report_start = Time.now
  conn = PGconn.open(:host => $config['host'], :port => $config['port'], :dbname => $config['dbname'], :user => $config['user'], :password => $config['password'])
  data_timestamp = get_data_timestamp(conn)

  cycleway_report_manager = OSMonitor::CyclewayReport::ReportManager.new(conn)
  road_report_manager = OSMonitor::RoadReport::ReportManager.new(conn)
  wiki_manager = WikiManager.new(cycleway_report_manager, road_report_manager)

  page = wiki_manager.get_osmonitor_page(input_page)
  old_page_text = page.text.dup
  wiki_manager.render_reports_on_page(page)

  puts "Page size (old = #{old_page_text.size}, new = #{page.text.size})"

  # Check if anything has changed - no point in uploading the same page only with updated timestamp.
  if old_page_text == page.text
    puts 'No change in the report - not uploading new version to the wiki!'
    exit
  end

  page.get_segments('DATA_TIMESTAMP').each {|segment| wiki_manager.replace_segment(page, segment, data_timestamp)}

  puts "Uploading to the wiki... (data timestamp = #{data_timestamp})"

  wiki_manager.login($config['wiki_username'], $config['wiki_password'])
  wiki_manager.save_page(page, output_page)

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

OSMonitor::run_wiki_reports(input_page, output_page)
