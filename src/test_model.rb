require "test/unit"
require "./model"

class ModelTest < Test::Unit::TestCase
  def test_road_walk_without_roles
    road = Road.new("S", "18", {})

    road.add_node(1, [NodeNeighbor.new(2, 100, '')])
    road.add_node(2, [NodeNeighbor.new(1, 100, ''), NodeNeighbor.new(3, 100, '')])
    road.add_node(3, [NodeNeighbor.new(2, 100, '')])

    a = road.connectivity
    
    assert_equal(2, a.size)
    assert_equal(1, a[0].size)
    assert_equal(nil, a[1])
  end

  def test_road_walk_without_roles_broken_neighbors
    road = Road.new("S", "18", {})

    road.add_node(1, [NodeNeighbor.new(2, 100, '')])
    road.add_node(2, [NodeNeighbor.new(1, 100, '')])
    road.add_node(3, [NodeNeighbor.new(4, 100, '')])
    road.add_node(4, [NodeNeighbor.new(3, 100, '')])

    a = road.connectivity
    
    assert_equal(2, a.size)
    assert_equal(2, a[0].size)
    assert_equal(nil, a[1])
  end

  def test_road_walk_with_roles
    road = Road.new("S", "18", {})

    road.add_node(1, [NodeNeighbor.new(2, 100, '')])
    road.add_node(2, [NodeNeighbor.new(1, 100, ''), NodeNeighbor.new(3, 100, 'backward'), NodeNeighbor.new(4, 100, 'forward')])
    road.add_node(3, [NodeNeighbor.new(2, 100, 'backward'), NodeNeighbor.new(5, 100, 'backward')])
    road.add_node(4, [NodeNeighbor.new(2, 100, 'forward'), NodeNeighbor.new(6, 100, 'forward')])
    road.add_node(5, [NodeNeighbor.new(3, 100, 'backward'), NodeNeighbor.new(7, 100, 'backward')])
    road.add_node(6, [NodeNeighbor.new(4, 100, 'forward'), NodeNeighbor.new(7, 100, 'forward')])
    road.add_node(7, [NodeNeighbor.new(5, 100, 'backward'), NodeNeighbor.new(6, 100, 'forward'), NodeNeighbor.new(8, 100, '')])
    road.add_node(8, [NodeNeighbor.new(7, 100, '')])

    a = road.connectivity

    assert_equal(2, a.size)
    assert_equal(1, a[0].size)
    assert_equal(1, a[1].size)
  end

  def test_road_walk_with_roles_broken_neighbors
    road = Road.new("S", "18", {})

    road.add_node(1, [NodeNeighbor.new(2, 100, '')])
    road.add_node(2, [NodeNeighbor.new(1, 100, ''), NodeNeighbor.new(3, 100, 'backward'), NodeNeighbor.new(4, 100, 'forward')])
    road.add_node(3, [NodeNeighbor.new(2, 100, 'backward')])
    road.add_node(4, [NodeNeighbor.new(2, 100, 'forward'), NodeNeighbor.new(6, 100, 'forward')])
    road.add_node(5, [NodeNeighbor.new(7, 100, 'backward')])
    road.add_node(6, [NodeNeighbor.new(4, 100, 'forward'), NodeNeighbor.new(7, 100, 'forward')])
    road.add_node(7, [NodeNeighbor.new(5, 100, 'backward'), NodeNeighbor.new(6, 100, 'forward'), NodeNeighbor.new(8, 100, '')])
    road.add_node(8, [NodeNeighbor.new(7, 100, '')])

    a = road.connectivity

    assert_equal(2, a.size)
    assert_equal(2, a[0].size)
    assert_equal(1, a[1].size)
  end

  def test_road_walk_with_roles_broken_backward_roles
    road = Road.new("S", "18", {})

    road.add_node(1, [NodeNeighbor.new(2, 100, '')])
    road.add_node(2, [NodeNeighbor.new(1, 100, ''), NodeNeighbor.new(3, 100, 'backward'), NodeNeighbor.new(4, 100, 'forward')])
    road.add_node(3, [NodeNeighbor.new(2, 100, 'backward'), NodeNeighbor.new(5, 100, 'forward')])
    road.add_node(4, [NodeNeighbor.new(2, 100, 'forward'), NodeNeighbor.new(6, 100, 'forward')])
    road.add_node(5, [NodeNeighbor.new(3, 100, 'forward'), NodeNeighbor.new(7, 100, 'backward')])
    road.add_node(6, [NodeNeighbor.new(4, 100, 'forward'), NodeNeighbor.new(7, 100, 'forward')])
    road.add_node(7, [NodeNeighbor.new(5, 100, 'backward'), NodeNeighbor.new(6, 100, 'forward'), NodeNeighbor.new(8, 100, '')])
    road.add_node(8, [NodeNeighbor.new(7, 100, '')])

    a = road.connectivity

    assert_equal(2, a.size)
    assert_equal(2, a[0].size)
    assert_equal(2, a[1].size)
  end

  def test_road_walk_with_roles_broken_forward_roles
    road = Road.new("S", "18", {})

    road.add_node(1, [NodeNeighbor.new(2, 100, '')])
    road.add_node(2, [NodeNeighbor.new(1, 100, ''), NodeNeighbor.new(3, 100, 'backward'), NodeNeighbor.new(4, 100, 'forward')])
    road.add_node(3, [NodeNeighbor.new(2, 100, 'backward'), NodeNeighbor.new(5, 100, 'backward')])
    road.add_node(4, [NodeNeighbor.new(2, 100, 'forward'), NodeNeighbor.new(6, 100, 'backward')])
    road.add_node(5, [NodeNeighbor.new(3, 100, 'backward'), NodeNeighbor.new(7, 100, 'backward')])
    road.add_node(6, [NodeNeighbor.new(4, 100, 'backward'), NodeNeighbor.new(7, 100, 'forward')])
    road.add_node(7, [NodeNeighbor.new(5, 100, 'backward'), NodeNeighbor.new(6, 100, 'forward'), NodeNeighbor.new(8, 100, '')])
    road.add_node(8, [NodeNeighbor.new(7, 100, '')])

    a = road.connectivity

    assert_equal(2, a.size)
    assert_equal(2, a[0].size)
    assert_equal(2, a[1].size)
  end
end
