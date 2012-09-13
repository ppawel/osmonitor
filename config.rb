# Environment specific stuff (URL's etc).
require 'config/environment'

# Sensitive stuff (passwords etc).
require 'config/sensitive'

module OSMonitor

@@config = {}

def self.config
  @@config
end

@@config['admin_report'] = {}
@@config['admin_report']['find_relation_sql_where_clause'] = {}

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
require 'config/poland'
require 'config/serbia'
