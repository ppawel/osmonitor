def get_relation_network(prefix)
  return $road_type_network_tag[prefix]
end

def create_overpass_url(ways)
  s = ''
  ways.each {|w| s += "way(#{w.id});"}
  "http://www.overpass-api.de/api/convert?data=(#{s});(._;node(w));out;&target=openlayers"
end

def create_osmonitor_url(road)
  "http://geowebhost.pl:3333/browse/road/#{road.ref_prefix + road.ref_number.to_s}"
end

$config = {

  'wiki_username' => '',
  'wiki_password' => '',
  'host' => 'localhost',
  'dbname' => 'osmdb',
  'user' => 'postgres',
  'password' => ''

}

$sql_where_by_road_type = {

  'A' => '"(r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\')"',

  'S' => '"(r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\')"',

  'DK' => '"((r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\') OR
    (r.tags -> \'ref\' = \'#{road.ref_number}\'))"',

  'DW' => '"((r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\') OR
    (r.tags -> \'ref\' = \'#{road.ref_number}\'))"'

}

# For "road type" (see Road#ref_prefix) defines proper "network" tag value for road relation.
$road_type_network_tag = {

  "A" => "pl:motorways",
  "S" => "pl:national",
  "DK" => "pl:national",
  "DW" => "pl:regional"

}

# For "road type" (see Road#ref_prefix) defines how "ref" tag should be constructed.
$road_type_ref_tag = {

  "A" => '"#{ref_prefix}#{ref_number}"',
  "S" => '"#{ref_prefix}#{ref_number}"',
  "DK" => '"#{ref_number}"',
  "DW" => '"#{ref_number}"'

}
