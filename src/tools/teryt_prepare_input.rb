require 'xml'
require 'unicode_utils'

def get_id(row)
  woj = row.find_first("col[@name='WOJ']").content
  pow = row.find_first("col[@name='POW']").content
  gmi = row.find_first("col[@name='GMI']").content
  rodz = row.find_first("col[@name='RODZ']").content
  "#{woj}#{pow}#{gmi}#{rodz}"
end

def get_parent_id(row)
  woj = row.find_first("col[@name='WOJ']").content
  pow = row.find_first("col[@name='POW']").content
  gmi = row.find_first("col[@name='GMI']").content
  rodz = row.find_first("col[@name='RODZ']").content
  return '1' if pow.empty?
  return "#{woj}" if gmi.empty?
  return "#{woj}#{pow}" if gmi.empty?
  return "#{woj}#{pow}"
end

def get_admin_level(row)
  woj = row.find_first("col[@name='WOJ']").content
  pow = row.find_first("col[@name='POW']").content
  gmi = row.find_first("col[@name='GMI']").content
  return '4' if pow.empty?
  return '6' if gmi.empty?

  rodz = row.find_first("col[@name='RODZ']").content

  return '7' if rodz == '1' or rodz == '2' or rodz == '3'
  return '8' if rodz == '4' or rodz == '5'
end

def get_name(row)
  row.find_first("col[@name='NAZWA']").content
end

def get_name_prefix(row)
  rodz = row.find_first("col[@name='RODZ']").content
  return 'gmina' if rodz == '1' or rodz == '2' or rodz == '3'
  row.find_first("col[@name='NAZDOD']").content
end

if ARGV.size == 0
  puts "Usage: teryt_prepare_input.rb <path to directory with TERYT XML files>"
  exit
end

teryt_dir = ARGV[0]

parser = XML::Parser.file("#{teryt_dir}/TERC.xml")
terc_doc = parser.parse

puts 'id,parent_id,admin_level,name,relation_name'
puts '1,,2,Polska,Polska'

terc_doc.find('/teryt/catalog/row', 't:http://teryt/').each do |el|
  # el is a <row> element, for example:
  # <row>
  # <col name='WOJ'>32</col>
  # <col name='POW'>63</col>
  # <col name='GMI'>01</col>
  # <col name='RODZ'>1</col>
  # <col name='NAZWA'>Świnoujście</col>
  # <col name='NAZDOD'>gmina miejska</col>
  # <col name='STAN_NA'>2012-05-09</col>
  # </row>

  admin_level = get_admin_level(el).to_i
  #next if admin_level > 6

  name = get_name(el)
  name = UnicodeUtils.downcase(name) if admin_level == 4 # DOLNOŚLĄSKIE, MAZOWIECKIE, POMORSKIE - don't scream at me!

  puts "#{get_id(el)},#{get_parent_id(el)},#{get_admin_level(el)},#{name},#{get_name_prefix(el)} #{name}"
end
