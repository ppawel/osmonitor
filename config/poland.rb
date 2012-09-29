# encoding: utf-8

module OSMonitor

# ADMIN REPORT

# SQL where clause by admin_level
@@config['admin_report']['find_relation_sql_where_clause']['PL'] = {
  '2' => '"r.tags->\'admin_level\' = \'2\' AND LOWER(r.tags->\'name\') = \'polska\'"',

  '4' => '"r.tags->\'admin_level\' = \'4\'
      AND LOWER(r.tags->\'name\') = \'województwo #{UnicodeUtils.downcase(boundary.input[\'name\'])}\'"',

  '6' => '"(LOWER(r.tags->\'name\') = \'powiat #{UnicodeUtils.downcase(boundary.input[\'name\'])}\' OR
        LOWER(r.tags->\'name\') = \'#{UnicodeUtils.downcase(boundary.input[\'name\'])}\' OR
        LOWER(r.tags->\'name\') ilike \'Miasto #{UnicodeUtils.downcase(boundary.input[\'name\'])}\') AND (r.tags->\'admin_level\' = \'6\' OR NOT r.tags?\'admin_level\')"',

  '7' => '"r.tags->\'admin_level\' = \'7\' AND LOWER(r.tags->\'name\') ~ \'(\s*)?#{UnicodeUtils.downcase(boundary.input[\'name\'])}\'"',

  '8' => '"r.tags->\'admin_level\' = \'8\' AND LOWER(r.tags->\'name\') ~ \'(\s*)?#{UnicodeUtils.downcase(boundary.input[\'name\'])}\'"',
}

# ROAD REPORT

@@config['road_report']['road_type_network_tag']['PL'] = {
  'A' => "pl:motorways",
  'S' => "pl:national",
  'DK' => "pl:national",
  'DW' => "pl:regional"
}

end
