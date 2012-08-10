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

    def handle_examine_edge(u, v)
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
    attr_accessor :prev
    attr_accessor :graph
    attr_accessor :source_node
    attr_accessor :target_node

    def initialize(graph, u, v)
      self.graph = graph
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
        break if u == @target_node

        @graph.each_adjacent(u) do |v|
          next if !q.has_key?(v)

          new_dist = dist + @graph.get_label(u, v).length
          if q[v].nil? or new_dist < q[v]
            @prev[v] = u
            q.change_priority(v, new_dist)
          end
        end
      end
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
end
