@config = {

  'wiki_username' => 'osmonitor',
  'wiki_password' => 'jakieshaslo',
  'host' => 'localhost',
  'dbname' => 'osmdb',
  'user' => 'postgres',
  'password' => ''

}

@sql_where_by_road_type = {

  'A' => '"(r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\')"',

  'S' => '"(r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\')"',

  'DK' => '"((r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\') OR
    (r.tags -> \'ref\' = \'#{road.ref_number}\'))"',

  'DW' => '"((r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\') OR
    (r.tags -> \'ref\' = \'#{road.ref_number}\'))"'

}
