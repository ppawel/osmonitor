$:.unshift '../../../' + File.dirname(__FILE__)
$:.unshift '../../../../' + File.dirname(__FILE__)

require 'test/unit'
require 'osmonitor/road_report/model'

module OSMonitor
module RoadReport

class DumbRoadComponent < RoadComponent
  def initialize
  end

  def oneway?
    false
  end

  def to_s
    "DumbRoadComponent"
  end
end

class DumbRoadComponentPath < RoadComponentPath
  def to_s
    "DumbRoadComponentPath"
  end
end

class ModelTest < Test::Unit::TestCase
  def test_roundtrip_sort
    forward_path = DumbRoadComponentPath.new(nil, nil, false, [WaySegment.new(nil, nil, nil, 100)])
    backward_path = DumbRoadComponentPath.new(nil, nil, false, [WaySegment.new(nil, nil, nil, 100)])
    roundtrip1 = RoadComponentRoundtrip.new(DumbRoadComponent.new, [], [], forward_path, backward_path)

    forward_path = DumbRoadComponentPath.new(nil, nil, true, [WaySegment.new(nil, nil, nil, 100)])
    backward_path = DumbRoadComponentPath.new(nil, nil, true, [WaySegment.new(nil, nil, nil, 100)])
    roundtrip2 = RoadComponentRoundtrip.new(DumbRoadComponent.new, [], [], forward_path, backward_path)

    forward_path = DumbRoadComponentPath.new(nil, nil, false, [WaySegment.new(nil, nil, nil, 200)])
    backward_path = DumbRoadComponentPath.new(nil, nil, false, [WaySegment.new(nil, nil, nil, 200)])
    roundtrip3 = RoadComponentRoundtrip.new(DumbRoadComponent.new, [], [], forward_path, backward_path)

    roundtrips = []
    roundtrips << roundtrip1
    roundtrips << roundtrip2
    roundtrips << roundtrip3

    roundtrips.sort!

    assert_equal(1, roundtrip2 <=> roundtrip1)
    assert_equal(1, roundtrip2 <=> roundtrip3)
    assert_equal(roundtrip2, roundtrips[2])
    assert_equal(roundtrip3, roundtrips[1])
    assert_equal(roundtrip1, roundtrips[0])
  end
end

end
end
