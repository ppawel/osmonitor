require 'config'

module OSMonitor
module CyclewayReport

class RoadManager < OSMonitor::RoadReport::RoadManager
  include OSMonitorLogger

  def get_find_relation_sql_where_clause(road)
    "r.tags -> 'type' = 'route' AND
    r.tags -> 'route' = 'bicycle' AND
    #{eval(OSMonitor.config['cycleway_report']['find_relation_sql_where_clause'][road.country][road.ref_prefix], binding())}"
  end

  def get_find_ways_sql_where_clause(road)
    eval(OSMonitor.config['cycleway_report']['find_ways_sql_where_clause'][road.country][road.ref_prefix], binding())
  end

  def get_sql_with_exceptions
    "(NOT w.tags ?| ARRAY['aerialway', 'aeroway', 'building', 'waterway']) AND
    ((w.tags -> 'railway') IS NULL OR (w.tags -> 'highway') IS NOT NULL)"
  end
end

end
end
