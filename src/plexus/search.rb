module Plexus
  # **Search/traversal algorithms.**
  #
  # This module defines a collection of search/traversal algorithms, in a unified API.
  # Read through the doc to get familiar with the calling pattern.
  #
  # Options are mostly callbacks passed in as a hash. The following are valid,
  # anything else is ignored:
  #
  # * `:enter_vertex`  => `Proc`  Called upon entry of a vertex.
  # * `:exit_vertex`   => `Proc`  Called upon exit of a vertex.
  # * `:root_vertex`   => `Proc`  Called when a vertex is the root of a tree.
  # * `:start_vertex`  => `Proc`  Called for the first vertex of the search.
  # * `:examine_edge`  => `Proc`  Called when an edge is examined.
  # * `:tree_edge`     => `Proc`  Called when the edge is a member of the tree.
  # * `:back_edge`     => `Proc`  Called when the edge is a back edge.
  # * `:forward_edge`  => `Proc`  Called when the edge is a forward edge.
  # * `:adjacent`      => `Proc` which, given a vertex, returns adjacent nodes, defaults to adjacent call of graph useful for changing the definition of adjacent in some algorithms.
  # * `:start`         => vertex  Specifies the vertex to start search from.
  #
  # If a `&block` instead of an option hash is specified, it defines `:enter_vertex`.
  #
  # Each search algorithm returns the list of vertexes as reached by `enter_vertex`.
  # This allows for calls like, `g.bfs.each { |v| ... }`
  #
  # Can also be called like `bfs_examine_edge { |e| ... }` or
  # `dfs_back_edge { |e| ... }` for any of the callbacks.
  #
  # A full example usage is as follows:
  #
  #     ev = Proc.new { |x| puts "Enter vertex #{x}" }
  #     xv = Proc.new { |x| puts "Exit vertex #{x}" }
  #     sv = Proc.new { |x| puts "Start vertex #{x}" }
  #     ee = Proc.new { |x| puts "Examine Arc #{x}" }
  #     te = Proc.new { |x| puts "Tree Arc #{x}" }
  #     be = Proc.new { |x| puts "Back Arc #{x}" }
  #     fe = Proc.new { |x| puts "Forward Arc #{x}" }
  #     Digraph[1,2, 2,3, 3,4].dfs({
  #        :enter_vertex => ev,
  #        :exit_vertex  => xv,
  #        :start_vertex => sv,
  #        :examine_edge => ee,
  #        :tree_edge    => te,
  #        :back_edge    => be,
  #        :forward_edge => fe })
  #
  # Which outputs:
  #
  #     Start vertex 1
  #     Enter vertex 1
  #     Examine Arc (1=2)
  #     Tree Arc (1=2)
  #     Enter vertex 2
  #     Examine Arc (2=3)
  #     Tree Arc (2=3)
  #     Enter vertex 3
  #     Examine Arc (3=4)
  #     Tree Arc (3=4)
  #     Enter vertex 4
  #     Examine Arc (1=4)
  #     Back Arc (1=4)
  #     Exit vertex 4
  #     Exit vertex 3
  #     Exit vertex 2
  #     Exit vertex 1
  #     => [1, 2, 3, 4]
  module Search

    # Performs a breadth-first search.
    #
    # @param [Hash] options
    def bfs(options = {}, &block)
      plexus_search_helper(:shift, options, &block)
    end
    alias :bread_first_search :bfs

    # Performs a depth-first search.
    #
    # @param [Hash] options
    def dfs(options = {}, &block)
      plexus_search_helper(:pop, options, &block)
    end
    alias :depth_first_search :dfs

    # Routine which computes a spanning forest for the given search method.
    # Returns two values: a hash of predecessors and an array of root nodes.
    #
    # @param [vertex] start
    # @param [Symbol] routine the search method (`:dfs`, `:bfs`)
    # @return [Array] predecessors and root nodes
    def spanning_forest(start, routine)
      predecessor = {}
      roots       = []
      te = Proc.new { |e| predecessor[e.target] = e.source }
      rv = Proc.new { |v| roots << v }
      send routine, :start => start, :tree_edge => te, :root_vertex => rv
      [predecessor, roots]
    end

    # Returns the dfs spanning forest for the given start node, see {Search#spanning_forest spanning_forest}.
    #
    # @param [vertex] start
    # @return [Array] predecessors and root nodes
    def dfs_spanning_forest(start)
      spanning_forest(start, :dfs)
    end

    # Returns the bfs spanning forest for the given start node, see {Search#spanning_forest spanning_forest}.
    #
    # @param [vertex] start
    # @return [Array] predecessors and root nodes
    def bfs_spanning_forest(start)
      spanning_forest(start, :bfs)
    end

    # Returns a hash of predecessors in a tree rooted at the start node. If this is a connected graph,
    # then it will be a spanning tree containing all vertices. An easier way to tell if it's a
    # spanning tree is to use a {Search#spanning_forest spanning_forest} call and check if there is a
    # single root node.
    #
    # @param [vertex] start
    # @param [Symbol] routine the search method (`:dfs`, `:bfs`)
    # @return [Hash] predecessors vertices
    def tree_from_vertex(start, routine)
      predecessor = {}
      correct_tree = false
      te = Proc.new { |e| predecessor[e.target] = e.source if correct_tree }
      rv = Proc.new { |v| correct_tree = (v == start) }
      send routine, :start => start, :tree_edge => te, :root_vertex => rv
      predecessor
    end

    # Returns a hash of predecessors for the depth-first search tree rooted at the given node.
    #
    # @param [vertex] start
    # @return [Hash] predecessors vertices
    def dfs_tree_from_vertex(start)
      tree_from_vertex(start, :dfs)
    end

    # Returns a hash of predecessors for the breadth-first search tree rooted at the given node.
    #
    # @param [Proc] start
    # @return [Hash] predecessors vertices
    def bfs_tree_from_vertex(start)
      tree_from_vertex(start, :bfs)
    end

    # An inner class used for greater efficiency in {Search#lexicograph_bfs}.
    #
    # Original design taken from Golumbic's, *Algorithmic Graph Theory and Perfect Graphs* pg. 87-89.
    class LexicographicQueue
      # Called with the initial values.
      #
      # @param [Array] initial vertices values
      def initialize(values)
        @node = Struct.new(:back, :forward, :data)
        @node.class_eval do
          def hash
            @hash
          end
          @@cnt = 0
        end
        @set  = {}
        @tail = @node.new(nil, nil, Array.new(values))
        @tail.instance_eval { @hash = (@@cnt += 1) }
        values.each { |a| @set[a] = @tail }
      end

      # Pops an entry with the maximum lexical value from the queue.
      #
      # @return [vertex]
      def pop
        return nil unless @tail
        value = @tail[:data].pop
        @tail = @tail[:forward] while @tail and @tail[:data].size == 0
        @set.delete(value)
        value
      end

      # Increase the lexical value of the given values.
      #
      # @param [Array] vertices values
      def add_lexeme(values)
        fix = {}

        values.select { |v| @set[v] }.each do |w|
          sw = @set[w]
          if fix[sw]
            s_prime = sw[:back]
          else
            s_prime = @node.new(sw[:back], sw, [])
            s_prime.instance_eval { @hash = (@@cnt += 1) }
            @tail = s_prime if @tail == sw
            sw[:back][:forward] = s_prime if sw[:back]
            sw[:back]           = s_prime
            fix[sw]             = true
          end

          s_prime[:data] << w
          sw[:data].delete(w)
          @set[w] = s_prime
        end

        fix.keys.select { |n| n[:data].size == 0 }.each do |e|
          e[:forward][:back] = e[:back]    if e[:forward]
          e[:back][:forward] = e[:forward] if e[:back]
        end
      end

    end

    # Lexicographic breadth-first search.
    #
    # The usual queue of vertices is replaced by a queue of *unordered subsets*
    # of the vertices, which is sometimes refined but never reordered.
    #
    # Originally developed by Rose, Tarjan, and Leuker, *Algorithmic
    # aspects of vertex elimination on graphs*, SIAM J. Comput. 5, 266-283
    # MR53 #12077
    #
    # Implementation taken from Golumbic's, *Algorithmic Graph Theory and
    # Perfect Graphs*, pg. 84-90.
    #
    # @return [vertex]
    def lexicograph_bfs(&block)
      lex_q = Plexus::Search::LexicographicQueue.new(vertices)
      result = []
      num_vertices.times do
        v = lex_q.pop
        result.unshift(v)
        lex_q.add_lexeme(adjacent(v))
      end
      result.each { |r| block.call(r) } if block
      result
    end

    # A* Heuristic best first search.
    #
    # `start` is the starting vertex for the search.
    #
    # `func` is a `Proc` that when passed a vertex returns the heuristic
    # weight of sending the path through that node. It must always
    # be equal to or less than the true cost.
    #
    # `options` are mostly callbacks passed in as a hash, the default block is
    # `:discover_vertex` and the weight is assumed to be the label for the {Arc}.
    # The following options are valid, anything else is ignored:
    #
    # * `:weight` => can be a `Proc`, or anything else is accessed using the `[]` for the
    #     the label or it defaults to using
    #     the value stored in the label for the {Arc}. If it is a `Proc` it will
    #     pass the edge to the proc and use the resulting value.
    # * `:discover_vertex` => `Proc` invoked when a vertex is first discovered
    #   and is added to the open list.
    # * `:examine_vertex`  => `Proc` invoked when a vertex is popped from the
    #   queue (i.e., it has the lowest cost on the open list).
    # * `:examine_edge`    => `Proc` invoked on each out-edge of a vertex
    #   immediately after it is examined.
    # * `:edge_relaxed`    => `Proc` invoked on edge `(u,v) if d[u] + w(u,v) < d[v]`.
    # * `:edge_not_relaxed`=> `Proc` invoked if the edge is not relaxed (see above).
    # * `:black_target`    => `Proc` invoked when a vertex that is on the closed
    #     list is "rediscovered" via a more efficient path, and is re-added
    #     to the open list.
    # * `:finish_vertex`    => Proc invoked on a vertex when it is added to the
    #     closed list, which happens after all of its out edges have been
    #     examined.
    #
    # Can also be called like `astar_examine_edge {|e| ... }` or
    # `astar_edge_relaxed {|e| ... }` for any of the callbacks.
    #
    # The criteria for expanding a vertex on the open list is that it has the
    # lowest `f(v) = g(v) + h(v)` value of all vertices on open.
    #
    # The time complexity of A* depends on the heuristic. It is exponential
    # in the worst case, but is polynomial when the heuristic function h
    # meets the following condition: `|h(x) - h*(x)| < O(log h*(x))` where `h*`
    # is the optimal heuristic, i.e. the exact cost to get from `x` to the `goal`.
    #
    # See also: [A* search algorithm](http://en.wikipedia.org/wiki/A*_search_algorithm) on Wikipedia.
    #
    # @param [vertex] start the starting vertex for the search
    # @param [vertex] goal the vertex to reach
    # @param [Proc] func heuristic weight computing process
    # @param [Hash] options
    # @return [Array(vertices), call, nil] an array of nodes in path, or calls block on all nodes,
    #   upon failure returns `nil`
    def astar(start, goal, func, options, &block)
      options.instance_eval "def handle_callback(sym,u) self[sym].call(u) if self[sym]; end"

      # Initialize.
      d = { start => 0 }
      color = { start => :gray } # Open is :gray, closed is :black.
      parent = Hash.new { |k| parent[k] = k }
      f = { start => func.call(start) }
      queue = PriorityQueue.new.push(start, f[start])
      block.call(start) if block

      # Process queue.
      until queue.empty?
        u, dummy = queue.delete_min
        options.handle_callback(:examine_vertex, u)

        # Unravel solution if the goal is reached.
        if u == goal
          solution = [goal]
          while u != start
            solution << parent[u]
            u = parent[u]
          end
          return solution.reverse
        end

        adjacent(u, :type => :edges).each do |e|
          v = e.source == u ? e.target : e.source
          options.handle_callback(:examine_edge, e)
          w = cost(e, options[:weight])
          raise ArgumentError unless w

          if d[v].nil? or (w + d[u]) < d[v]
            options.handle_callback(:edge_relaxed, e)
            d[v] = w + d[u]
            f[v] = d[v] + func.call(v)
            parent[v] = u

            unless color[v] == :gray
              options.handle_callback(:black_target, v) if color[v] == :black
              color[v] = :gray
              options.handle_callback(:discover_vertex, v)
              queue.push v, f[v]
              block.call(v) if block
            end
          else
            options.handle_callback(:edge_not_relaxed, e)
          end
        end # adjacent(u)

        color[u] = :black
        options.handle_callback(:finish_vertex, u)
      end # queue.empty?

      nil # failure, on fall through
    end # astar

    # `best_first` has all the same options as {Search#astar astar}, with `func` set to `h(v) = 0`.
    # There is an additional option, `zero`, which should be defined as the zero element
    # for the `+` operation performed on the objects used in the computation of cost.
    #
    # @param [vertex] start the starting vertex for the search
    # @param [vertex] goal the vertex to reach
    # @param [Proc] func heuristic weight computing process
    # @param [Hash] options
    # @param [Integer] zero (0)
    # @return [Array(vertices), call, nil] an array of nodes in path, or calls block on all nodes,
    #   upon failure returns `nil`
    def best_first(start, goal, options, zero = 0, &block)
      func = Proc.new { |v| zero }
      astar(start, goal, func, options, &block)
    end

    # @private
    alias_method :pre_search_method_missing, :method_missing
    def method_missing(sym, *args, &block)
      m1 = /^dfs_(\w+)$/.match(sym.to_s)
      dfs((args[0] || {}).merge({ m1.captures[0].to_sym => block })) if m1
      m2 = /^bfs_(\w+)$/.match(sym.to_s)
      bfs((args[0] || {}).merge({ m2.captures[0].to_sym => block })) if m2
      pre_search_method_missing(sym, *args, &block) unless m1 or m2
    end

    private

    # Performs the search using a specific algorithm and a set of options.
    #
    # @param [Symbol] op the algorithm to be used te perform the search
    # @param [Hash] options
    # @return [Object] result
    def plexus_search_helper(op, options = {}, &block)
      return nil if size == 0
      result = []

      # Create the options hash handling callbacks.
      options = {:enter_vertex => block, :start => to_a[0]}.merge(options)
      options.instance_eval "def handle_vertex(sym,u) self[sym].call(u) if self[sym]; end"
      options.instance_eval "def handle_edge(sym,e) self[sym].call(e) if self[sym]; end"

      # Create a waiting list, which is a queue or a stack, depending on the op specified.
      # The first entry is the start vertex.
      waiting = [options[:start]]
      waiting.instance_eval "def next; #{op.to_s}; end"

      # Create a color map, all elements set to "unvisited" except for start vertex,
      # which will be set to waiting.
      color_map = vertices.inject({}) { |a,v| a[v] = :unvisited; a }
      color_map.merge!(waiting[0] => :waiting)
      options.handle_vertex(:start_vertex, waiting[0])
      options.handle_vertex(:root_vertex,  waiting[0])

      # Perform the actual search until nothing is "waiting".
      until waiting.empty?
        # Loop till the search iterator exhausts the waiting list.
        visited_edges = {} # This prevents retraversing edges in undirected graphs.
        until waiting.empty?
          plexus_search_iteration(options, waiting, color_map, visited_edges, result, op == :pop)
        end
        # Waiting for the list to be exhausted, check if a new root vertex is available.
        u = color_map.detect { |key,value| value == :unvisited }
        waiting.push(u[0]) if u
        options.handle_vertex(:root_vertex, u[0]) if u
      end

      result
    end

    # Performs a search iteration (step).
    #
    # @private
    def plexus_search_iteration(options, waiting, color_map, visited_edges, result, recursive = false)
      # Fetch the next waiting vertex in the list.
      #sleep
      u = waiting.next
      options.handle_vertex(:enter_vertex, u)
      result << u

      # Examine all adjacent outgoing edges, but only those not previously traversed.
      adj_proc = options[:adjacent] || self.method(:adjacent).to_proc
      adj_proc.call(u, :type => :edges, :direction => :out).reject { |w| visited_edges[w] }.each do |e|
        e = e.reverse unless directed? or e.source == u # Preserves directionality where required.
        v = e.target
        options.handle_edge(:examine_edge, e)
        visited_edges[e] = true

        case color_map[v]
          # If it's unvisited, it goes into the waiting list.
        when :unvisited
          options.handle_edge(:tree_edge, e)
          color_map[v] = :waiting
          waiting.push(v)
          # If it's recursive (i.e. dfs), then call self.
          plexus_search_iteration(options, waiting, color_map, visited_edges, result, true) if recursive
        when :waiting
          options.handle_edge(:back_edge, e)
        else
          options.handle_edge(:forward_edge, e)
        end
      end

      # Done with this vertex!
      options.handle_vertex(:exit_vertex, u)
      color_map[u] = :visited
    end

    public

    # Topological Sort Iterator.
    #
    # The topological sort algorithm creates a linear ordering of the vertices
    # such that if edge (u,v) appears in the graph, then u comes before v in
    # the ordering. The graph must be a directed acyclic graph (DAG).
    #
    # The iterator can also be applied to undirected graph or to a DG graph
    # which contains a cycle. In this case, the Iterator does not reach all
    # vertices. The implementation of acyclic? and cyclic? uses this fact.
    #
    # Can be called with a block as a standard ruby iterator, or can
    # be used directly as it will return the result as an Array.
    #
    # @param [vertex] start (nil) the start vertex (nil will fallback on the first
    #   vertex inserted within the graph)
    # @return [Array] a linear representation of the sorted graph
    def topsort(start = nil, &block)
      result  = []
      go      = true
      back    = Proc.new { |e| go = false }
      push    = Proc.new { |v| result.unshift(v) if go }
      start ||= vertices[0]
      dfs({ :exit_vertex => push, :back_edge => back, :start => start })
      result.each { |v| block.call(v) } if block
      result
    end

    # Does a top sort, but trudges forward if a cycle occurs. Use with caution.
    #
    # @param [vertex] start (nil) the start vertex (nil will fallback on the first
    #   vertex inserted within the graph)
    # @return [Array] a linear representation of the sorted graph
    def sort(start = nil, &block)
      result  = []
      push    = Proc.new { |v| result.unshift(v) }
      start ||= vertices[0]
      dfs({ :exit_vertex => push, :start => start })
      result.each { |v| block.call(v) } if block
      result
    end

    # Returns true if a graph contains no cycles, false otherwise.
    #
    # @return [Boolean]
    def acyclic?
      topsort.size == size
    end

    # Returns false if a graph contains no cycles, true otherwise.
    #
    # @return [Boolean]
    def cyclic?
      not acyclic?
    end
  end
end
