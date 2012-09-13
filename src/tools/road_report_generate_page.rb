#!/usr/bin/ruby

require 'erb'

if ARGV.size == 0
  exit
end

wiki_template_name = ARGV[0]

layout = ERB.new File.read("erb/road_report_layout.erb")
road_refs = STDIN.read.lines.collect {|ref| ref.to_i}
puts layout.result
