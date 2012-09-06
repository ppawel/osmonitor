require 'priority_queue/ruby_priority_queue'
require 'rgl/base'
require 'stream'

module RGL
  # Finds *any* path from u to v.
  class PathIterator < BFSIterator
    attr_accessor :path
    attr_accessor :found_path
    attr_accessor :target
    attr_accessor :stop_after

    def initialize(graph, u, v, stop_after = 2 << 64)
      self.path = []
      self.found_path = false
      self.stop_after = stop_after
      self.target = v
      super(graph, u)
    end

    def at_end?
      found_path or @waiting.empty? or @path.size == stop_after
    end

    protected

    def handle_tree_edge(u, v)
      return if !u or !v
      @path << u
      @path << v
    end

    def handle_finish_vertex(v)
      @found_path = true if v == @target
    end
  end

  # Finds shortest paths from u to all other vertices using the Dijkstra algorithm.
  class DijkstraIterator
    attr_accessor :dist
    attr_accessor :prev
    attr_accessor :graph
    attr_accessor :source_node
    attr_accessor :target_node

    def initialize(graph, u, v)
      self.graph = graph
      self.dist = {}
      self.prev = {}
      self.source_node = u
      self.target_node = v
    end

    def go
      q = RubyPriorityQueue.new
      @graph.vertices.each {|v| q.push(v, 2 << 64) if v != @source_node}
      q.push(@source_node, 0.0)

      while !q.empty? do
        u, dist = q.delete_min
        @dist[u] = dist
        #break if u == @target_node

        @graph.each_adjacent(u) do |v|
          next if !q.has_key?(v)
          label = @graph.get_label(u, v)
          label = @graph.get_label(v, u) if !label and !@graph.directed?
          new_dist = dist + label.length
          if q[v].nil? or new_dist < q[v]
            @prev[v] = u
            q.change_priority(v, new_dist)
          end
        end
      end

      @dist.each {|node, dist| @dist.delete(node) if dist == 2 << 64}
    end

    def to(v)
      path = []
      u = v
      while prev[u] do
        path.unshift(u)
        u = prev[u]
      end
      path.unshift(@source_node)
      path
    end
  end

  module Graph
    attr_accessor :dijkstras

    def max_dist(node)
      calculate_dijkstra([node])
      #puts @dijkstras[node].dist
      @dijkstras[node].dist.max_by {|node, dist| dist}
    end

    def dist(node1, node2)
      calculate_dijkstra([node1, node2])
      @dijkstras[node1].dist[node2]
    end

    def path(from, to)
      calculate_dijkstra([from, to])
      @dijkstras[from].to(to)
    end

    def furthest(nodes, node_from)
      calculate_dijkstra(nodes + [node_from])
      nodes.max_by {|node_to| @dijkstras[node_from].dist[node_to] ? @dijkstras[node_from].dist[node_to] : -1}
    end

    # Returns a pair of nodes (and the distance between them) that are furthest apart.
    def furthest_pair_of_nodes(nodes)
      max = -1
      max_pair = nil

      nodes.each do |node|
        furthest = furthest(nodes, node)
        next if furthest == node

        dist = dist(node, furthest)

        if dist > max
          max = dist
          max_pair = node, furthest
        end
      end

      max_pair
    end

    def calculate_dijkstra(nodes)
      @dijkstras = {} if !@dijkstras

      nodes.each do |node|
        next if @dijkstras.has_key?(node)
        it = RGL::DijkstraIterator.new(self, node, nil)
        it.go
        @dijkstras[node] = it
      end
    end
  end
end
