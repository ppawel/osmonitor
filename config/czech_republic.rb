module OSMonitor

# CYCLEWAY REPORT

@@config['cycleway_report']['find_relation_sql_where_clause']['CR'] = {
  '' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\')"'
}

@@config['cycleway_report']['find_ways_sql_where_clause']['CR'] = {
  '' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'])"'
}

@@config['cycleway_report']['road_type_ref_tag']['CR'] = {
  '' => '"#{ref_number}"'
}

@@config['cycleway_report']['road_type_network_tag']['CR'] = {
  '' => nil
}

# ROAD REPORT

@@config['road_report']['find_relation_sql_where_clause']['CR'] = {
  'D' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\')"',
  'R' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\')"'
}

@@config['road_report']['find_ways_sql_where_clause']['CR'] = {
  'D' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'])"',
  'R' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'])"'
}

@@config['road_report']['road_type_ref_tag']['CR'] = {
  'D' => '"#{ref_prefix}#{ref_number}"',
  'R' => '"#{ref_prefix}#{ref_number}"'
}

@@config['road_report']['road_type_network_tag']['CR'] = {
  'D' => nil,
  'R' => nil
}

end
