module OSMonitor

# ROAD REPORT

@@config['road_report']['find_relation_sql_where_clause']['RS'] = {
  'E' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\' OR r.tags @>  \'\"ref\"=>\"#{road.ref_number}\"\')"',
  'M' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\' OR r.tags @>  \'\"ref\"=>\"#{road.ref_number}\"\')"',
  'R' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\' OR r.tags @>  \'\"ref\"=>\"#{road.ref_number}\"\')"'
}

@@config['road_report']['find_ways_sql_where_clause']['RS'] = {
  'E' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'] OR w.refs @> ARRAY[\'#{road.ref_number}\'])"',
  'M' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'] OR w.refs @> ARRAY[\'#{road.ref_number}\'])"',
  'R' => '"(w.refs @> ARRAY[replace(\'#{road.ref_prefix + road.ref_number}\', \'.\', \'-\')] OR w.refs @> ARRAY[replace(\'#{road.ref_prefix + road.ref_number}\', \'-\', \'.\')] OR
    w.refs @> ARRAY[replace(\'#{road.ref_number}\', \'.\', \'-\')] OR w.refs @> ARRAY[replace(\'#{road.ref_number}\', \'-\', \'.\')])"'
}

@@config['road_report']['road_type_ref_tag']['RS'] = {
  'E' => '"#{ref_prefix}#{ref_number}"',
  'M' => '"#{ref_prefix}#{ref_number}"',
  'R' => '"#{ref_prefix}#{ref_number}"'
}

@@config['road_report']['road_type_network_tag']['RS'] = {
  'M' => "RS:national",
  'R' => "RS:regional"
}

end
