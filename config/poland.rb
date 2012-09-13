# encoding: utf-8

module OSMonitor

# ADMIN REPORT

# SQL where clause by admin_level
@@config['admin_report']['find_relation_sql_where_clause']['PL'] = {
  '2' => '"r.tags->\'admin_level\' = \'2\' AND LOWER(r.tags->\'name\') = \'polska\'"',

  '4' => '"r.tags->\'admin_level\' = \'4\'
      AND LOWER(r.tags->\'name\') = \'województwo #{UnicodeUtils.downcase(boundary.input[\'name\'])}\'"'
}

# ROAD REPORT

@@config['road_report']['find_relation_sql_where_clause']['PL'] = {
  'A' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\')"',

  'S' => '"(r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\')"',

  'DK' => '"((r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\') OR
    (r.tags -> \'ref\' = \'#{road.ref_number}\'))"',

  'DW' => '"((r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\') OR
    (r.tags -> \'ref\' = \'#{road.ref_number}\'))"'
}

@@config['road_report']['find_ways_sql_where_clause']['PL'] = {
  'A' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'])"',
  'S' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'])"',
  'DK' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'] OR w.refs @> ARRAY[\'#{road.ref_number}\'])"',
  'DW' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'] OR w.refs @> ARRAY[\'#{road.ref_number}\'])"'
}

@@config['road_report']['road_type_ref_tag']['PL'] = {
  'A' => '"#{ref_prefix}#{ref_number}"',
  'S' => '"#{ref_prefix}#{ref_number}"',
  'DK' => '"#{ref_number}"',
  'DW' => '"#{ref_number}"'
}

@@config['road_report']['road_type_network_tag']['PL'] = {
  'A' => "pl:motorways",
  'S' => "pl:national",
  'DK' => "pl:national",
  'DW' => "pl:regional"
}

end
