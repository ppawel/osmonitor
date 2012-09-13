#!/usr/bin/ruby

require 'media_wiki'

mw = MediaWiki::Gateway.new('https://pl.wikipedia.org/w/api.php')
page = mw.get ARGV[0]
pattern = ARGV[1]

puts page.scan(/#{pattern}/).collect { |x| x[0].to_i }.uniq.sort


