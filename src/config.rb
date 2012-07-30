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
