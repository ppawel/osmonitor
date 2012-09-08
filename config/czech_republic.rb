module OSMonitor

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

@@config['road_report']['find_relation_sql_where_clause']['CR'] = {
  '' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\')"'
}

@@config['road_report']['find_ways_sql_where_clause']['CR'] = {
  '' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'])"'
}


end
