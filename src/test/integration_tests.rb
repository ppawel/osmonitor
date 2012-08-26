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
    road.relation = Relation.new(1, {})
  end

  def get_node_xy(node_id)
    return 1, 2
  end

  def road_data_from_file(file_name)
    eval(File.open(file_name).gets)
  end
end

class IntegrationTests < Test::Unit::TestCase
  # Handy helper to load road data from file for a given road.
  def setup_from_file
  Proc.new  {|ref_prefix, ref_number|
    road_manager = RoadManager.new(nil)

    def road_manager.load_ways(road)
      road_data_from_file("road_data_#{road.ref_prefix}#{road.ref_number}.txt")
    end

    @road = road_manager.load_road('PL', ref_prefix, ref_number)
    @status = RoadStatus.new(@road)
    }
  end

  def test_simple_road
    road_manager = RoadManager.new(nil)

    def road_manager.load_ways(road)
      [{'member_role' => '', 'way_id' => 100, 'node_id' => 1, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 1000},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 1000},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 1000},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 3, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 1000},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 4, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 1000}]
    end

    road = road_manager.load_road('PL', 'A', '1')
    status = RoadStatus.new(road)
    status.validate
    assert(status.issues.size > 0)
    assert(!status.has_issue_by_name?('road_disconnected'))
    assert_equal(3, road.length.to_i)
  end

  # This road has ways directed like this ---><--- - but they are two way so it's OK.
  def test_simple_road_ways_misdirected
    road_manager = RoadManager.new(nil)

    def road_manager.load_ways(road)
      [{'member_role' => '', 'way_id' => 100, 'node_id' => 1, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 1000},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 1000},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 4, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 1000},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 3, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 1000},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 1000}]
    end

    road = road_manager.load_road('PL', 'A', '1')
    status = RoadStatus.new(road)
    status.validate
    assert(status.issues.size > 0)
    assert(!status.has_issue_by_name?('road_disconnected'))
    puts road.comps[0].graph
    assert_equal(3, road.length.to_i)
  end

  def test_disconnected_relation
    road_manager = RoadManager.new(nil)

    def road_manager.load_ways(road)
      [{'member_role' => '', 'way_id' => 100, 'node_id' => 1, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 95500},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 85500},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 75500},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 3, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 65500},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 4, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 55500},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 6, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 45500},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 7, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 35500},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 8, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 25500},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 9, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 15500}]
    end

    road = road_manager.load_road('PL', 'A', '1')
    status = RoadStatus.new(road)
    status.validate
    assert_equal(2, road.num_comps)
    assert_equal(2, road.num_logical_comps)
    assert(status.has_issue_by_name?('road_disconnected'))
  end

  def test_shortest_path
    road_manager = RoadManager.new(nil)

    def road_manager.load_ways(road)
      [{'member_role' => '', 'way_id' => 100, 'node_id' => 1, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 100},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 100},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 2, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'node_dist_to_next' => 100},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 3, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'node_dist_to_next' => 100},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 4, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'node_dist_to_next' => 100},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 7, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'node_dist_to_next' => 100},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 7, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'node_dist_to_next' => 33},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 6, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'node_dist_to_next' => 33},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 5, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'node_dist_to_next' => 33},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 2, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'node_dist_to_next' => 33},
      {'member_role' => '', 'way_id' => 103, 'node_id' => 7, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 5500},
      {'member_role' => '', 'way_id' => 103, 'node_id' => 8, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 5500},
      {'member_role' => '', 'way_id' => 104, 'node_id' => 8, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 66},
      {'member_role' => '', 'way_id' => 104, 'node_id' => 9, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 66}]
    end

    road = road_manager.load_road('PL', 'A', '1')
    status = RoadStatus.new(road)
    status.validate

    assert(!status.issues.detect {|i| i.name == 'relation_disconnected'})
    assert_equal(1, status.road.comps.size)
    #assert_equal(2, status.road.comps[0].paths.size)
    #puts status.road.comps[0].paths[0].segmentse.inspect
    #assert_equal(521.0, status.road.comps[0].paths[0].length)
    #assert_equal(320.0, status.road.comps[0].paths[1].length)
  end

  def test_y_shaped_road
    road_manager = RoadManager.new(nil)

    def road_manager.load_ways(road)
      [{'member_role' => '', 'way_id' => 100, 'node_id' => 2, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'node_dist_to_next' => 1000},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 1, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'node_dist_to_next' => 1000},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 3, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'node_dist_to_next' => 1000},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 2, 'way_tags' => {'highway' => 'primary', 'oneway' => 'yes'}, 'node_dist_to_next' => 1000},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 2, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 5500},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 4, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 5500},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 5, 'way_tags' => {'highway' => 'primary'}, 'node_dist_to_next' => 5500}]
    end

    road = road_manager.load_road('PL', 'A', '1')
    status = RoadStatus.new(road)
    status.validate

    assert(!status.has_issue_by_name?('road_disconnected'))
    assert(!status.has_issue_by_name?('not_navigable'))
    assert_equal(1, status.road.comps.size)
    assert_equal(12, road.length.to_i)
  end

  def test_dk47
    instance_eval { setup_from_file.call('DK', '47') }
    @status.validate
    assert(@status.has_issue_by_name?('road_disconnected'))
    assert_equal(4, @road.num_comps)
  end

  def test_dw103
    instance_eval { setup_from_file.call('DW', '103') }
    @status.validate
    assert(!@status.has_issue_by_name?('relation_disconnected'))
    #puts road.comps[0].end_nodes
    #road.comps[0].roundtrip
  end

  def test_dw303
    instance_eval { setup_from_file.call('DW', '303') }
    @status.validate
    assert(!@status.has_issue_by_name?('road_disconnected'))
    assert(!@status.has_issue_by_name?('not_navigable'))
    assert_equal(40, @road.length.to_i)
  end

  def test_dw255
    instance_eval { setup_from_file.call('DW', '255') }
    @status.validate
    assert(!@status.has_issue_by_name?('road_disconnected'))
    #assert_equal(@road.get_node(259982309), @road.comps[0].furthest(@road.get_node(683182935)))
    #assert(!road.length.nil?)
  end

  def test_dw796
    instance_eval { setup_from_file.call('DW', '796') }
    @status.validate

    assert(!@status.has_issue_by_name?('relation_disconnected'))
    #assert_equal(1, @road.num_comps)
    #assert_equal(2, @road.comps[0].end_nodes.size)
    #assert_equal(road.get_node(259982309), road.comps[0].furthest(road.get_node(683182935)))
    #assert(!road.length.nil?)
  end

  def test_dk54
    instance_eval { setup_from_file.call('DK', '54') }
    @status.validate
    assert(!@status.has_issue_by_name?('road_disconnected'))
    assert_equal(18, @road.length.to_i)
  end

  def test_dk82
    instance_eval { setup_from_file.call('DK', '82') }
    @status.validate
    assert(!@status.has_issue_by_name?('road_disconnected'))
    assert_equal(85, @road.length.to_i)
  end

  def test_dw138
    instance_eval { setup_from_file.call('DW', '138') }
    @status.validate
    assert(!@status.has_issue_by_name?('road_disconnected'))
    assert(@status.has_issue_by_name?('not_navigable'))
    #assert_equal(3, @road.comps[0].end_nodes.size)
    assert(@road.comps[0].end_nodes.include?(@road.get_node(37822512)))
    assert(@road.comps[0].end_nodes.include?(@road.get_node(268983476)))
    assert(@road.comps[0].end_nodes.include?(@road.get_node(1211699340)))
    assert_equal(nil, @road.length)
  end

  def test_dk81
    instance_eval { setup_from_file.call('DK', '81') }
    @status.validate
    assert(!@road.comps[0].oneway?)
    assert(!@road.comps[1].oneway?)
    assert_equal(2, @road.num_comps)
    assert_equal(2, @road.num_logical_comps)
    assert(@status.has_issue_by_name?('road_disconnected'))
    assert(@road.comps[0].wkt_points)
    assert(@road.comps[1].wkt_points)
  end

  # This road has some ways without the highway tag - these should be ignored, let's test for that.
  def test_dw530
    instance_eval { setup_from_file.call('DW', '530') }
    @status.validate
    assert(@status.has_issue_by_name?('road_disconnected'))
    assert_equal(2, @road.num_comps)
  end

  # This road has no end nodes - starts and ends with a roundabout... support it maybe in the future?
  def test_dw471
    instance_eval { setup_from_file.call('DW', '471') }
    @status.validate
    assert(!@status.has_issue_by_name?('road_disconnected'))
    assert_equal(1, @road.num_comps)
    assert_equal(0, @road.comps[0].end_nodes.size)
  end

  # This road has a very convoluted end nodes but still it should (? - TBD) be navigable.
  def test_dw102
    instance_eval { setup_from_file.call('DW', '102') }
    @status.validate
    assert(!@status.has_issue_by_name?('road_disconnected'))
    assert(!@status.has_issue_by_name?('not_navigable'))
    assert_equal(1, @road.num_comps)
    #assert_equal(5, @road.comps[0].end_nodes.size)
  end

  # This road needs better error (failed paths) reporting.
  def test_dw812
    instance_eval { setup_from_file.call('DW', '812') }
    @status.validate
    assert(!@status.has_issue_by_name?('road_disconnected'))
    assert(@status.has_issue_by_name?('not_navigable'))
    assert_equal(1, @road.num_comps)
    assert(@road.comps[0].roundtrip.failed_paths.size > 0)
  end

  # This road has some strange end nodes. Should be navigable.
  def test_dw967
    instance_eval { setup_from_file.call('DW', '967') }
    @status.validate
    assert(!@status.has_issue_by_name?('road_disconnected'))
    assert(!@status.has_issue_by_name?('not_navigable'))
  end

  # This road has two oneway components.
  def test_a18
    instance_eval { setup_from_file.call('A', '18') }
    @status.validate
    assert_equal(true, @road.comps[0].oneway?)
    assert_equal(true, @road.comps[1].oneway?)
    assert_equal(2, @road.num_comps)
    assert_equal(1, @road.num_logical_comps)
    assert(!@status.has_issue_by_name?('not_navigable'))
    #assert_equal(7, @road.length.to_i)
  end

  # This road has two oneway components.
  def test_a8
    instance_eval { setup_from_file.call('A', '8') }
    @status.validate
    assert_equal(true, @road.comps[0].oneway?)
    assert_equal(true, @road.comps[1].oneway?)
    assert_equal(2, @road.num_comps)
    assert_equal(1, @road.num_logical_comps)
    assert(!@status.has_issue_by_name?('not_navigable'))
    assert_equal(21, @road.length.to_i)
  end

  # This road should be navigable.
  def test_dw406
    instance_eval { setup_from_file.call('DW', '406') }
    @status.validate
    assert_equal(1, @road.num_comps)
    assert_equal(1, @road.num_logical_comps)
    assert(!@status.has_issue_by_name?('not_navigable'))
    assert_equal(20, @road.length.to_i)
  end

  def test_a4
    instance_eval { setup_from_file.call('A', '4') }
    @status.validate
    assert_equal(2, @road.num_comps)
    assert_equal(1, @road.num_logical_comps)
    assert(!@status.has_issue_by_name?('not_navigable'))
    assert_equal(443, @road.length.to_i)
  end

  def test_dw456
    instance_eval { setup_from_file.call('DW', '456') }
    @status.validate
    assert_equal(1, @road.num_comps)
    assert_equal(1, @road.num_logical_comps)
    assert(!@status.has_issue_by_name?('not_navigable'))
    assert_equal(0, @road.length.to_i)
  end

  def test_dw100
    instance_eval { setup_from_file.call('DW', '100') }
    @status.validate
    assert_equal(1, @road.num_comps)
    assert_equal(1, @road.num_logical_comps)
    assert(!@status.has_issue_by_name?('not_navigable'))
    assert_equal(0, @road.length.to_i)
  end

  # https://github.com/ppawel/osmonitor/issues/18
  # Roundabout is actually below the road.
  def test_dk50
    instance_eval { setup_from_file.call('DK', '50') }
    @status.validate
    assert_equal(2, @road.num_comps)
    assert_equal(2, @road.num_logical_comps)
    assert(@status.has_issue_by_name?('road_disconnected'))
  end

  def test_d5
    instance_eval { setup_from_file.call('D', '5') }
    @status.validate
    assert_equal(true, @road.comps[0].oneway?)
    assert_equal(true, @road.comps[1].oneway?)
    assert_equal(1, @road.num_comps)
    assert_equal(1, @road.num_logical_comps)
    assert(!@status.has_issue_by_name?('not_navigable'))
    assert_equal(0, @road.length.to_i)
  end

  def test_dk98
    instance_eval { setup_from_file.call('DK', '98') }
    @status.validate
    assert_equal(1, @road.num_comps)
    assert_equal(1, @road.num_logical_comps)
    assert(!@status.has_issue_by_name?('road_disconnected'))
  end
end

end
