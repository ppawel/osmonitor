require 'rgeo'

require 'config'
require 'osmonitor/core'

def distance_between(node1, node2)
  return nil if !node1.point_wkt or !node2.point_wkt
  point1 = $rgeo_factory.parse_wkt(node1.point_wkt)
  point2 = $rgeo_factory.parse_wkt(node2.point_wkt)
  point1.distance(point2)
end

module OSMonitor
module AdminReport

class Boundary
  include OSMonitorLogger

  attr_accessor :country
  attr_accessor :input
  attr_accessor :relation
  attr_accessor :other_relations

  def initialize(country, input)
    self.country = country
    self.input = input
    self.other_relations = []
  end
end

end
end
