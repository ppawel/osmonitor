require "test/unit"
require "./road_graph"

class RoadGraphTest < Test::Unit::TestCase
  def test_simple_road_graph_simple
    data = [
      {'member_role' => '', 'way_id' => 100, 'node_id' => 1},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 3},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 4},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 5}
    ]

    road = Road.new('A', '7', {})
    road.graph.load(data)

    assert_equal(5, road.graph.all_graph.num_vertices)
    assert_equal(5, road.graph.backward_graph.num_vertices)
    assert_equal(5, road.graph.forward_graph.num_vertices)
    
    assert_equal(4, road.graph.all_graph.num_edges)
    assert_equal(4, road.graph.backward_graph.num_edges)
    assert_equal(4, road.graph.forward_graph.num_edges)

    assert_equal(1, comps(road.graph.all_graph).size)
  end

  def test_simple_road_graph_same_node
    data = [
      {'member_role' => '', 'way_id' => 100, 'node_id' => 1},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 1},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2}
    ]

    road = Road.new('A', '7', {})
    road.graph.load(data)

    assert_equal(2, road.graph.all_graph.num_vertices)
    assert_equal(2, road.graph.backward_graph.num_vertices)
    assert_equal(2, road.graph.forward_graph.num_vertices)

    assert_equal(1, comps(road.graph.all_graph).size)
    # TODO (is 3?)
    #assert_equal(1, road.graph.all_graph.num_edges)
    #assert_equal(1, road.graph.backward_graph.num_edges)
    #assert_equal(1, road.graph.forward_graph.num_edges)
  end

  def test_simple_road_graph_three_ways
    data = [
      {'member_role' => '', 'way_id' => 100, 'node_id' => 1},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 2},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 3},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 4},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 4},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 5},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 6},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 7},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 8}
    ]

    road = Road.new('A', '7', {})
    road.graph.load(data)

    assert_equal(8, road.graph.all_graph.num_vertices)
    assert_equal(8, road.graph.backward_graph.num_vertices)
    assert_equal(8, road.graph.forward_graph.num_vertices)

    assert_equal(7, road.graph.all_graph.num_edges)
    assert_equal(7, road.graph.backward_graph.num_edges)
    assert_equal(7, road.graph.forward_graph.num_edges)

    assert_equal(1, comps(road.graph.all_graph).size)
  end

  def test_simple_road_graph_node_in_two_ways
    data = [
      {'member_role' => '', 'way_id' => 100, 'node_id' => 1},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 2},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 3},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 4},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 3},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 7},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 8}
    ]

    road = Road.new('A', '7', {})
    road.graph.load(data)

    assert_equal(6, road.graph.all_graph.num_vertices)
    assert_equal(6, road.graph.backward_graph.num_vertices)
    assert_equal(6, road.graph.forward_graph.num_vertices)

    assert_equal(5, road.graph.all_graph.num_edges)
    assert_equal(5, road.graph.backward_graph.num_edges)
    assert_equal(5, road.graph.forward_graph.num_edges)

    assert_equal(1, comps(road.graph.all_graph).size)
  end

   def test_simple_road_graph_disconnected
    data = [
      {'member_role' => '', 'way_id' => 100, 'node_id' => 1},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 2},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 3},
      {'member_role' => '', 'way_id' => 101, 'node_id' => 4},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 6},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 7},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 8},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 9}
    ]

    road = Road.new('A', '7', {})
    road.graph.load(data)

    assert_equal(8, road.graph.all_graph.num_vertices)
    assert_equal(8, road.graph.backward_graph.num_vertices)
    assert_equal(8, road.graph.forward_graph.num_vertices)

    assert_equal(6, road.graph.all_graph.num_edges)
    assert_equal(6, road.graph.backward_graph.num_edges)
    assert_equal(6, road.graph.forward_graph.num_edges)

    assert_equal(2, comps(road.graph.all_graph).size)
  end

  def test_roundabout
    data = [
      {'member_role' => '', 'way_id' => 100, 'node_id' => 1},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 3},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 4},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 5},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 6},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 7},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 1}
    ]

    road = Road.new('A', '7', {})
    road.graph.load(data)

    assert_equal(7, road.graph.all_graph.num_vertices)
    assert_equal(7, road.graph.backward_graph.num_vertices)
    assert_equal(7, road.graph.forward_graph.num_vertices)

    assert_equal(7, road.graph.all_graph.num_edges)
    assert_equal(7, road.graph.backward_graph.num_edges)
    assert_equal(7, road.graph.forward_graph.num_edges)

    assert_equal(1, comps(road.graph.all_graph).size)
  end

  def test_roles
    data = [
      {'member_role' => '', 'way_id' => 100, 'node_id' => 1},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2},
      {'member_role' => 'backward', 'way_id' => 101, 'node_id' => 2},
      {'member_role' => 'backward', 'way_id' => 101, 'node_id' => 3},
      {'member_role' => 'backward', 'way_id' => 101, 'node_id' => 4},
      {'member_role' => 'backward', 'way_id' => 101, 'node_id' => 5},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 5},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 6},
      {'member_role' => 'forward', 'way_id' => 103, 'node_id' => 2},
      {'member_role' => 'forward', 'way_id' => 103, 'node_id' => 7},
      {'member_role' => 'forward', 'way_id' => 103, 'node_id' => 8},
      {'member_role' => 'forward', 'way_id' => 103, 'node_id' => 5}
    ]

    road = Road.new('A', '7', {})
    road.graph.load(data)

    assert_equal(4, road.graph.all_graph.num_vertices)
    assert_equal(6, road.graph.backward_graph.num_vertices)
    assert_equal(6, road.graph.forward_graph.num_vertices)

    assert_equal(2, road.graph.all_graph.num_edges)
    assert_equal(5, road.graph.backward_graph.num_edges)
    assert_equal(5, road.graph.forward_graph.num_edges)

    assert_equal(2, comps(road.graph.all_graph).size)
  end

  def test_roles_mislabeled_backward
    data = [
      {'member_role' => '', 'way_id' => 100, 'node_id' => 1},
      {'member_role' => '', 'way_id' => 100, 'node_id' => 2},
      {'member_role' => 'backward', 'way_id' => 101, 'node_id' => 2},
      {'member_role' => 'backward', 'way_id' => 101, 'node_id' => 3},
      {'member_role' => 'backward', 'way_id' => 105, 'node_id' => 4},
      {'member_role' => 'backward', 'way_id' => 105, 'node_id' => 5},
      {'member_role' => 'forward', 'way_id' => 112, 'node_id' => 3},
      {'member_role' => 'forward', 'way_id' => 112, 'node_id' => 4},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 5},
      {'member_role' => '', 'way_id' => 102, 'node_id' => 6},
      {'member_role' => 'forward', 'way_id' => 103, 'node_id' => 2},
      {'member_role' => 'forward', 'way_id' => 103, 'node_id' => 7},
      {'member_role' => 'forward', 'way_id' => 103, 'node_id' => 8},
      {'member_role' => 'forward', 'way_id' => 103, 'node_id' => 5}
    ]

    road = Road.new('A', '7', {})
    road.graph.load(data)

    assert_equal(4, road.graph.all_graph.num_vertices)
    assert_equal(6, road.graph.backward_graph.num_vertices)
    assert_equal(8, road.graph.forward_graph.num_vertices)

    assert_equal(2, road.graph.all_graph.num_edges)
    assert_equal(4, road.graph.backward_graph.num_edges)
    assert_equal(6, road.graph.forward_graph.num_edges)

    assert_equal(2, comps(road.graph.backward_graph).size)
    puts road.graph.suggest_backward_fixes.inspect
  end
=begin  
  def test_long_way
    data = []

    (1..2000).each {|x| data << {'member_role' => '', 'way_id' => 100, 'node_id' => x}}

    road = Road.new('A', '7', {})
    road.graph.load(data)

    assert_equal(2000, road.graph.all_graph.num_vertices)
    assert_equal(2000, road.graph.backward_graph.num_vertices)
    assert_equal(2000, road.graph.forward_graph.num_vertices)

    assert_equal(1999, road.graph.all_graph.num_edges)
    assert_equal(1999, road.graph.backward_graph.num_edges)
    assert_equal(1999, road.graph.forward_graph.num_edges)

    assert_equal(1, comps(road.graph.all_graph).size)
  end
=end
  def comps(g)
    c = []
    return g.connected_components_nonrecursive
  end
end
