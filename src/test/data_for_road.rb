$:.unshift '../' + File.dirname(__FILE__)

require 'elogger'
require 'core'

require 'pg'
require 'erb'
require 'media_wiki'

require 'config'
require 'road_manager'
require 'wiki'

if ARGV.size != 3
  puts 'Usage: data_for_road.rb <country> <ref_prefix> <ref_number>'
  exit
end

conn = PGconn.open(:host => $config['host'], :port => $config['port'], :dbname => $config['dbname'], :user => $config['user'], :password => $config['password'])
road_manager = OSMonitor::RoadManager.new(conn)
road_data = road_manager.get_road_data(ARGV[0], ARGV[1], ARGV[2])

data = []
road_data.each_with_index {|row, i| data << road_data[i]}
puts data.inspect
