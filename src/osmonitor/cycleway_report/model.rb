require 'rgeo'

require 'config'
require 'osmonitor'

module OSMonitor
module CyclewayReport

$rgeo_factory = ::RGeo::Geographic.spherical_factory()

def distance_between(node1, node2)
  return nil if !node1.point_wkt or !node2.point_wkt
  point1 = $rgeo_factory.parse_wkt(node1.point_wkt)
  point2 = $rgeo_factory.parse_wkt(node2.point_wkt)
  point1.distance(point2)
end

class Road < OSMonitor::RoadReport::Road

end

end
end
