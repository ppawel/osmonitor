require 'config_sensitive'

def get_relation_network(prefix)
  return $road_type_network_tag[prefix]
end

def create_overpass_url(ways)
  s = ''
  ways.each {|w| s += "way(#{w.id});"}
  "http://www.overpass-api.de/api/convert?data=(#{s});(._;node(w));out;&target=openlayers"
end

def create_osmonitor_url(road)
  "http://geowebhost.pl/osmonitor/browse/road/#{road.ref_prefix + road.ref_number.to_s}"
end

$sql_where_by_road_type_ways = {

  'A' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'])"',

  'S' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'])"',

  'DK' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'] OR w.refs @> ARRAY[\'#{road.ref_number}\'])"',

  'DW' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'] OR w.refs @> ARRAY[\'#{road.ref_number}\'])"'
}

$sql_where_by_road_type_relations = {

  'A' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\')"',

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
