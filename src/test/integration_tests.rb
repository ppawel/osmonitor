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

  def road_data_from_file(file_name)
    eval(File.open(file_name).gets)
  end
end

class IntegrationTests < Test::Unit::TestCase
  def test_simple_road
    road_manager = RoadManager.new(nil)

    def road_manager.load_relation_ways(road)
      [{'member_role' => '', 'way_id' => 100, 'node_id' => 1, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2, 'way_tags' => {}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 3, 'way_tags' => {}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 4, 'way_tags' => {}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 5, 'way_tags' => {}, 'way_length' => 55}]
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
      [{'member_role' => '', 'way_id' => 100, 'node_id' => 1, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 3, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 4, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 6, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 7, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 8, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 9, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55}]
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
    #assert_equal(2, status.road.relation_comps[0].paths.size)
    #puts status.road.relation_comps[0].paths[0].segmentse.inspect
    assert_equal(521.0, status.road.relation_comps[0].paths[0].length)
    assert_equal(320.0, status.road.relation_comps[0].paths[1].length)
  end

  def test_y_shaped_road
    road_manager = RoadManager.new(nil)

    def road_manager.load_relation_ways(road)
      [{'member_role' => '', 'way_id' => 100, 'node_id' => 2, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'way_length' => 100},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 1, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'way_length' => 100},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 3, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'way_length' => 100},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 2, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'way_length' => 100},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 4, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 55},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 5, 'way_tags' => {'highway' => 'primary'}, 'way_length' => 66}]
    end

    input = RoadInput.new
    road = road_manager.load_road('A', '1')
    status = RoadStatus.new(input, road)
    status.validate

    assert(!status.has_issue_by_name?('relation_disconnected'))
    assert(!status.has_issue_by_name?('not_navigable'))
    assert_equal(1, status.road.relation_comps.size)
    #assert_equal(2, status.road.relation_comps[0].paths.size)
    assert_equal(155.0, road.relation_comps[0].dist(road.get_node(3), road.get_node(4)))
    assert_equal(210.0, road.relation_comps[0].dist(road.get_node(5), road.get_node(1)))
    assert_equal(road.get_node(1), road.relation_comps[0].furthest(road.get_node(5)))
    assert_equal(road.get_node(5), road.relation_comps[0].furthest(road.get_node(3)))
    assert_equal(road.get_node(3), road.relation_comps[0].closest_end_nodes(road.get_node(3))[0])
    assert_equal(road.get_node(3), road.relation_comps[0].closest_end_nodes(road.get_node(1))[1])
    road.relation_comps[0].roundtrip
  end

  def test_dk47
    road_manager = RoadManager.new(nil)

    def road_manager.load_relation_ways(road)
      road_data_from_file('road_data_DK47.txt')
    end

    input = RoadInput.new
    road = road_manager.load_road('DK', '47')
    status = RoadStatus.new(input, road)
    status.validate
  end

  def test_dw103
    road_manager = RoadManager.new(nil)

    def road_manager.load_relation_ways(road)
      road_data_from_file('road_data_DW103.txt')
    end

    input = RoadInput.new
    road = road_manager.load_road('DW', '103')
    status = RoadStatus.new(input, road)
    status.validate

    assert(!status.has_issue_by_name?('relation_disconnected'))
    #puts road.relation_comps[0].end_nodes
    #road.relation_comps[0].roundtrip
  end

  def test_dw303
    road_manager = RoadManager.new(nil)

    def road_manager.load_relation_ways(road)
      road_data_from_file('road_data_DW303.txt')
    end

    input = RoadInput.new
    road = road_manager.load_road('DW', '303')
    status = RoadStatus.new(input, road)
    status.validate

    assert(!
    status.has_issue_by_name?('relation_disconnected'))
    assert(!road.length.nil?)
  end

  def test_dk74
    road_manager = RoadManager.new(nil)

    def road_manager.load_relation_ways(road)
      road_data_from_file('road_data_DK74.txt')
    end

    input = RoadInput.new
    road = road_manager.load_road('DK', '74')
    status = RoadStatus.new(input, road)
    status.validate

    assert(!status.has_issue_by_name?('relation_disconnected'))
    puts road.length
    assert_equal(road.get_node(259982309), road.relation_comps[0].furthest(road.get_node(683182935)))
    assert(!road.length.nil?)
  end

  def test_dw255
    road_manager = RoadManager.new(nil)

    def road_manager.load_relation_ways(road)
      road_data_from_file('road_data_DW255.txt')
    end

    input = RoadInput.new
    road = road_manager.load_road('DW', '255')
    status = RoadStatus.new(input, road)
    status.validate

    assert(!status.has_issue_by_name?('relation_disconnected'))
    puts road.relation_comps[0].end_nodes.inspect
    #assert_equal(road.get_node(259982309), road.relation_comps[0].furthest(road.get_node(683182935)))
    #assert(!road.length.nil?)
  end
end

end
