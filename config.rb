# Environment specific stuff (URL's etc).
require 'config/environment'

# Sensitive stuff (passwords etc).
require 'config/sensitive'

module OSMonitor

@@config = {}

def self.config
  @@config
end

@@config['cycleway_report'] = {}
@@config['cycleway_report']['find_relation_sql_where_clause'] = {}
@@config['cycleway_report']['find_ways_sql_where_clause'] = {}
@@config['cycleway_report']['road_type_ref_tag'] = {}
@@config['cycleway_report']['road_type_network_tag'] = {}

@@config['road_report'] = {}
@@config['road_report']['find_relation_sql_where_clause'] = {}
@@config['road_report']['find_ways_sql_where_clause'] = {}
@@config['road_report']['road_type_ref_tag'] = {}
@@config['road_report']['road_type_network_tag'] = {}

end

require 'config/czech_republic'

def create_overpass_url(ways)
  s = ''
  ways.each {|w| s += "way(#{w.id});"}
  "http://www.overpass-api.de/api/convert?data=(#{s});(._;node(w));out;&target=openlayers"
end

$sql_where_by_road_type_ways = {

  'PL' => {
    'A' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'])"',

    'S' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'])"',

    'DK' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'] OR w.refs @> ARRAY[\'#{road.ref_number}\'])"',

    'DW' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'] OR w.refs @> ARRAY[\'#{road.ref_number}\'])"'
  },

  'RS' => {
    'E' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'] OR w.refs @> ARRAY[\'#{road.ref_number}\'])"',
    'M' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'] OR w.refs @> ARRAY[\'#{road.ref_number}\'])"',
    'R' => '"(w.refs @> ARRAY[replace(\'#{road.ref_prefix + road.ref_number}\', \'.\', \'-\')] OR w.refs @> ARRAY[replace(\'#{road.ref_prefix + road.ref_number}\', \'-\', \'.\')] OR
      w.refs @> ARRAY[replace(\'#{road.ref_number}\', \'.\', \'-\')] OR w.refs @> ARRAY[replace(\'#{road.ref_number}\', \'-\', \'.\')])"'
  },

  'CZ' => {
    'D' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'])"',
    'R' => '"(w.refs @> ARRAY[\'#{road.ref_prefix + road.ref_number}\'])"'
  }
}

$sql_where_by_road_type_relations = {

  'PL' => {
    'A' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\')"',

    'S' => '"(r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\')"',

    'DK' => '"((r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\') OR
      (r.tags -> \'ref\' = \'#{road.ref_number}\'))"',

    'DW' => '"((r.tags -> \'ref\' ilike \'#{road.ref_prefix + road.ref_number}\' OR replace(r.tags -> \'ref\', \' \', \'\') ilike \'#{road.ref_prefix + road.ref_number}\') OR
      (r.tags -> \'ref\' = \'#{road.ref_number}\'))"'
  },

  'RS' => {
    'E' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\' OR r.tags @>  \'\"ref\"=>\"#{road.ref_number}\"\')"',
    'M' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\' OR r.tags @>  \'\"ref\"=>\"#{road.ref_number}\"\')"',
    'R' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\' OR r.tags @>  \'\"ref\"=>\"#{road.ref_number}\"\')"'
  },

  'CZ' => {
    'D' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\')"',
    'R' => '"(r.tags @>  \'\"ref\"=>\"#{road.ref_prefix + road.ref_number}\"\')"'
  }
}

# For "road type" (see Road#ref_prefix) defines proper "network" tag value for road relation.
$road_type_network_tag = {

  'PL' => {
    'A' => "pl:motorways",
    'S' => "pl:national",
    'DK' => "pl:national",
    'DW' => "pl:regional"
  },

  'RS' => {
    'M' => "RS:national",
    'R' => "RS:regional"
  },

  'CZ' => {
    'D' => nil,
    'R' => nil
  }

}

# For "road type" (see Road#ref_prefix) defines how "ref" tag should be constructed.
$road_type_ref_tag = {

  'PL' => {
    'A' => '"#{ref_prefix}#{ref_number}"',
    'S' => '"#{ref_prefix}#{ref_number}"',
    'DK' => '"#{ref_number}"',
    'DW' => '"#{ref_number}"'
  },

  'RS' => {
    'E' => '"#{ref_prefix}#{ref_number}"',
    'M' => '"#{ref_prefix}#{ref_number}"',
    'R' => '"#{ref_prefix}#{ref_number}"'
  },

  'CZ' => {
    'D' => '"#{ref_prefix}#{ref_number}"',
    'R' => '"#{ref_prefix}#{ref_number}"'
  }

}
