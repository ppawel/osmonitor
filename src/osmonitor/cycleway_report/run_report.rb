$:.unshift File.absolute_path(File.dirname(__FILE__) + '/../../')
$:.unshift File.absolute_path(File.dirname(__FILE__) + '/../../../')

require 'osmonitor'
require 'erb'

module OSMonitor

include OSMonitorLogger

@overall_report = RoadReport.new

def read_input
end

def self.render_stats(report)
  ERB.new(File.read("erb/road_report_stats.erb")).result(binding())
end

def self.get_data_timestamp(conn)
  conn.query("SELECT OSM_GetDataTimestamp()").getvalue(0, 0)
end

def self.run_report(input_page, output_page)
  report_start = Time.now
  conn = PGconn.open(:host => $config['host'], :port => $config['port'], :dbname => $config['dbname'], :user => $config['user'], :password => $config['password'])
  data_timestamp = get_data_timestamp(conn)

  road_manager = RoadManager.new(conn)
  report_manager = ReportManager.new(road_manager)
  wiki_manager = WikiManager.new

  page = wiki_manager.get_osmonitor_page(input_page)
  old_page_text = page.text.dup

  page.get_segments('CYCLEWAY_REPORT').each do |segment|
    country = segment.params['country']
    refs = []
    refs = segment.params['refs'].split(',') if segment.params['refs']
    ref_prefix = segment.params['ref_prefix']
    report_text = nil

    if !refs.empty?
      report, report_text = report_manager.generate_road_report(country, refs)
      @overall_report.add(report)
    elsif !ref_prefix.empty?
      IO.readlines("../data/road_refs/#{country}_#{ref_prefix}.txt").each {|ref| refs << "#{ref_prefix}#{ref.gsub(/\n/, '')}"}
      report, report_text = report_manager.generate_road_report(country, refs)
      @overall_report.add(report)
    end

    wiki_manager.replace_segment(page, segment, report_text)
  end

  page.get_segments('ROAD_STATS').each {|segment| wiki_manager.replace_segment(page, segment, render_stats(@overall_report))}

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

OSMonitor.run_report(input_page, output_page)
