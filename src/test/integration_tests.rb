$:.unshift '../' + File.dirname(__FILE__)

require 'elogger'
require 'core'

require 'net/http'
require 'erb'
require 'media_wiki'

require 'config'
require 'road_manager'
require 'wiki'

require "test/unit"

module OSMonitor

# We don't use Postgres here in tests so replace some database-using methods.
class RoadManager
  def fill_road_relation(road)
    road.relation = {'id' => 1, 'tags' => {} }
  end

  def get_node_xy(node_id)
    return 1, 2
  end
end

class IntegrationTests < Test::Unit::TestCase
  def test_simple_road
    road_manager = RoadManager.new(nil)

    def road_manager.load_relation_ways(road)
      [{'member_role' => '', 'way_id' => 100, 'node_id' => 1, 'way_tags' => {'highway' => 'primary'}},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2, 'way_tags' => {}},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 3, 'way_tags' => {}},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 4, 'way_tags' => {}},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 5, 'way_tags' => {}}]
    end

    input = RoadInput.new
    road = road_manager.load_road('A', '1')
    status = RoadStatus.new(input, road)
    status.validate
    assert(status.issues.size > 0)
    assert(!status.issues.detect {|i| i.name == 'relation_disconnected'})
  end

  def test_disconnected_relation
    road_manager = RoadManager.new(nil)

    def road_manager.load_relation_ways(road)
      [{'member_role' => '', 'way_id' => 100, 'node_id' => 1, 'way_tags' => {'highway' => 'primary'}},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 3, 'way_tags' => {'highway' => 'primary'}},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 4, 'way_tags' => {'highway' => 'primary'}},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 6, 'way_tags' => {'highway' => 'primary'}},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 7, 'way_tags' => {'highway' => 'primary'}},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 8, 'way_tags' => {'highway' => 'primary'}},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 9, 'way_tags' => {'highway' => 'primary'}}]
    end

    input = RoadInput.new
    road = road_manager.load_road('A', '1')
    status = RoadStatus.new(input, road)
    status.validate
    assert(status.issues.detect {|i| i.name == 'relation_disconnected'})
  end

  def test_shortest_path
    road_manager = RoadManager.new(nil)

    def road_manager.load_relation_ways(road)
      [{'member_role' => '', 'way_id' => 100, 'node_id' => 1, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 100},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 100},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 2, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'way_length' => 100},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 3, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'way_length' => 100},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 4, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'way_length' => 100},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 7, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'way_length' => 100},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 7, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'way_length' => 33},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 6, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'way_length' => 33},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 5, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'way_length' => 33},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 2, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'way_length' => 33},
      {'member_role' => '', 'way_id' => 103, 'node_id' => 7, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 103, 'node_id' => 8, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 104, 'node_id' => 8, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 66},
      {'member_role' => '', 'way_id' => 104, 'node_id' => 9, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 66}]
    end

    input = RoadInput.new
    road = road_manager.load_road('A', '1')
    status = RoadStatus.new(input, road)
    status.validate

    assert(!status.issues.detect {|i| i.name == 'relation_disconnected'})
    assert_equal(1, status.road.relation_comps.size)
    assert_equal(2, status.road.relation_comps[0].paths.size)
    assert_equal(321.0, status.road.relation_comps[0].paths[0].length)
    assert_equal(254.0, status.road.relation_comps[0].paths[1].length)
  end
end

end
