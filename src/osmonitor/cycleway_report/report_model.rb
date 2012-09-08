module OSMonitor
module CyclewayReport

class RoadStatus < OSMonitor::RoadReport::RoadStatus
  def get_proper_network
    OSMonitor.config['cycleway_report']['road_type_network_tag'][road.country][road.ref_prefix]
  end
end

class RoadIssue
  attr_accessor :name
  attr_accessor :type
  attr_accessor :data

  def initialize(type, name, data)
    self.type = type
    self.name = name
    self.data = data
  end

  def to_s
    "RoadIssue(#{type}, #{name})"
  end
end

class RoadReport < OSMonitor::RoadReport::RoadReport
end

end
end
