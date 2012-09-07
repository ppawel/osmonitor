$:.unshift File.absolute_path(File.dirname(__FILE__) + '/../../')
$:.unshift File.absolute_path(File.dirname(__FILE__) + '/../../../')

require 'osmonitor'
require 'erb'

module OSMonitor

include OSMonitorLogger

REPORT_BEGIN = "<!-- OSMonitor ROADREPORT -->"
REPORT_END = "<!-- OSMonitor /ROADREPORT -->"
TIMESTAMP_BEGIN = "<!-- OSMonitor TIMESTAMP -->"
TIMESTAMP_END = "<!-- OSMonitor /TIMESTAMP -->"
STATS_BEGIN = "<!-- OSMonitor STATS -->"
STATS_END = "<!-- OSMonitor /STATS -->"

@overall_report = RoadReport.new

def self.insert_stats(page_text, report)
  stats_text = ERB.new(File.read("erb/road_report_stats.erb")).result(binding())
  page_text.gsub!(/#{Regexp.escape(STATS_BEGIN)}.*?#{Regexp.escape(STATS_END)}/mi,
    STATS_BEGIN + stats_text + STATS_END)
end

def self.get_data_timestamp(conn)
  return conn.query("SELECT OSM_GetDataTimestamp()").getvalue(0, 0)
end

def self.insert_data_timestamp(page_text, conn)
  timestamp = get_data_timestamp(conn)
  page_text.gsub!(/#{Regexp.escape(TIMESTAMP_BEGIN)}.*?#{Regexp.escape(TIMESTAMP_END)}/,
    TIMESTAMP_BEGIN + timestamp + TIMESTAMP_END)
  timestamp
end

def self.run_report(input_page, output_page)
  report_start = Time.now
  conn = PGconn.open(:host => $config['host'], :port => $config['port'], :dbname => $config['dbname'], :user => $config['user'], :password => $config['password'])
  road_manager = RoadManager.new(conn)
  report_manager = ReportManager.new(road_manager)
  mw = MediaWiki::Gateway.new('https://wiki.openstreetmap.org/w/api.php')
  page_text = mw.get(input_page)
  old_page_text = page_text.dup

  old_page_text.scan(/((<\!\-\- OSMonitor ROADREPORT (.*?) \-\->).*?(#{Regexp.escape(REPORT_END)}))/mi) do |match|
    all = match[0]
    beginning = $2
    args = $3
    ending = $4
    country = args.scan(/country\=(\w+)/i)[0][0]
    refs = args.scan(/refs=(.*)/i)
    ref_prefix = args.scan(/ref_prefix=(.*)/i)
    report_text = nil

    if !refs.empty?
      refs = refs[0][0]
      report, report_text = report_manager.generate_road_report(country, refs.split(','))
      @overall_report.add(report)
    elsif !ref_prefix.empty?
      ref_prefix = ref_prefix[0][0]
      refs = []
      IO.readlines("../data/road_refs/#{country}_#{ref_prefix}.txt").each {|ref| refs << "#{ref_prefix}#{ref.gsub(/\n/, '')}"}
      report, report_text = report_manager.generate_road_report(country, refs)
      @overall_report.add(report)
    end

    page_text[all] = "#{beginning}#{report_text}#{ending}" if report_text
  end

  insert_stats(page_text, @overall_report)

  puts "Page size (old = #{old_page_text.size}, new = #{page_text.size})"

  # Check if anything has changed - no point in uploading the same page only with updated timestamp.
  if old_page_text == page_text
    puts 'No change in the report - not uploading new version to the wiki!'
    exit
  end

  timestamp = insert_data_timestamp(page_text, conn)

  puts "Uploading to the wiki... (data timestamp = #{timestamp})"

  mw.login($config['wiki_username'], $config['wiki_password'])
  mw.create(output_page, page_text, :overwrite => true, :summary => 'Automated')

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
