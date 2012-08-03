module Plexus
  # Using only a basic methods set, it implements all the *basic* functions
  # of a graph. The process is under the control of the pattern
  # {AdjacencyGraphBuilder}, unless a specific implementation is specified
  # during initialization.
  #
  # An actual, complete implementation still needs to be done using this cheap result,
  # hence {Digraph}, {UndirectedGraph} and their roomates.
  module GraphBuilder
    include Enumerable
    include Labels
    include Dot

    #def self.[](*a)
      #puts self
      #self.new.from_array(*a)
    #end
    # after the class->module transition, has been moved at implementation level,
    # using a helper (extends_host)
    #
    extends_host
    module ClassMethods
      def [](*a)
        self.new.from_array(*a)
      end
    end

    # Creates a generic graph.
    #
    # @param [Hash(Plexus::Graph, Array)] *params initialization parameters.
    #   See {AdjacencyGraphBuilder#implementation_initialize} for more details.
    # @return [Graph]
    #
    def initialize(*params)
      raise ArgumentError if params.any? do |p|
        # FIXME: checking wether it's a GraphBuilder (module) is not sufficient
        # and the is_a? redefinition trick (instance_evaling) should be
        # completed by a clever way to check the actual class of p.
        # Maybe using ObjectSpace to get the available Graph classes?
        !(p.is_a? Plexus::GraphBuilder or p.is_a? Array or p.is_a? Hash)
      end

      args = params.last || {}

      class << self
        self
      end.module_eval do
        # These inclusions trigger some validations checks by the way.
        include(args[:implementation]       ? args[:implementation]       : Plexus::AdjacencyGraphBuilder)
        include(args[:algorithmic_category] ? args[:algorithmic_category] : Plexus::DigraphBuilder       )
      end

      implementation_initialize(*params)
    end

    # Shortcut for creating a Graph.
    #
    # Using an arry of implicit {Arc}, specifying the vertices:
    #
    #     Plexus::Graph[1,2, 2,3, 2,4, 4,5].edges.to_a.to_s
    #     # => "(1-2)(2-3)(2-4)(4-5)"
    #
    # Using a Hash for specifying labels along the way:
    #
    #     Plexus::Graph[ [:a,:b] => 3, [:b,:c] => 4 ]  (note: do not use for Multi or Pseudo graphs)
    #
    # @param [Array, Hash] *a
    # @return [Graph]
    def from_array(*a)
      if a.size == 1 and a[0].is_a? Hash
        # Convert to edge class
        a[0].each do |k,v|
          #FIXME, edge class shouldn't be assume here!!!
          if edge_class.include? Plexus::ArcNumber
            add_edge!(edge_class[k[0],k[1],nil,v])
          else
            add_edge!(edge_class[k[0],k[1],v])
          end
        end
        #FIXME, edge class shouldn't be assume here!!!
      elsif a[0].is_a? Plexus::Arc
        a.each{ |e| add_edge!(e); self[e] = e.label}
      elsif a.size % 2 == 0
        0.step(a.size-1, 2) {|i| add_edge!(a[i], a[i+1])}
      else
        raise ArgumentError
      end
      self
    end

    # Non destructive version of {AdjacencyGraphBuilder#add_vertex!} (works on a copy of the graph).
    #
    # @param [vertex] v
    # @param [Label] l
    # @return [Graph] a new graph with the supplementary vertex
    def add_vertex(v, l = nil)
      x = self.class.new(self)
      x.add_vertex!(v, l)
    end

    # Non destructive version {AdjacencyGraphBuilder#add_edge!} (works on a copy of the graph).
    #
    # @param [vertex] u
    # @param [vertex] v
    # @param [Label] l
    # @return [Graph] a new graph with the supplementary edge
    def add_edge(u, v = nil, l = nil)
      x = self.class.new(self)
      x.add_edge!(u, v, l)
    end
    alias add_arc add_edge

    # Non destructive version of {AdjacencyGraphBuilder#remove_vertex!} (works on a copy of the graph).
    #
    # @param [vertex] v
    # @return [Graph] a new graph without the specified vertex
    def remove_vertex(v)
      x = self.class.new(self)
      x.remove_vertex!(v)
    end

    # Non destructive version {AdjacencyGraphBuilder#remove_edge!} (works on a copy of the graph).
    #
    # @param [vertex] u
    # @param [vertex] v
    # @return [Graph] a new graph without the specified edge
    def remove_edge(u, v = nil)
      x = self.class.new(self)
      x.remove_edge!(u, v)
    end
    alias remove_arc remove_edge

    # Computes the adjacent portions of the Graph.
    #
    # The options specify the parameters about the adjacency search.
    # Note: it is probably more efficently done in the implementation class.
    #
    # @param [vertex, Edge] x can either be a vertex an edge
    # @option options [Symbol] :type (:vertices) can be either `:edges` or `:vertices`
    # @option options [Symbol] :direction (:all) can be `:in`, `:out` or `:all`
    # @return [Array] an array of the adjacent portions
    # @fixme
    def adjacent(x, options = {})
      d = directed? ? (options[:direction] || :out) : :all

      # Discharge the easy ones first.
      return [x.source] if x.is_a? Arc and options[:type] == :vertices and d == :in
      return [x.target] if x.is_a? Arc and options[:type] == :vertices and d == :out
      return [x.source, x.target] if x.is_a? Arc and options[:type] != :edges and d == :all

      (options[:type] == :edges ? edges : to_a).select { |u| adjacent?(x,u,d) }
    end
    #FIXME: This is a hack around a serious problem
    alias graph_adjacent adjacent

    # Adds all specified vertices to the vertex set.
    #
    # @param [#each] *a an Enumerable vertices set
    # @return [Graph] `self`
    def add_vertices!(*a)
      a.each { |v| add_vertex! v }
      self
    end

    # Same as {GraphBuilder#add_vertices! add_vertices!} but works on copy of the receiver.
    #
    # @param [#each] *a
    # @return [Graph] a modified copy of `self`
    def add_vertices(*a)
      x = self.class.new(self)
      x.add_vertices!(*a)
      self
    end

    # Adds all edges mentionned in the specified Enumerable to the edge set.
    #
    # Elements of the Enumerable can be either two-element arrays or instances of
    # {Edge} or {Arc}.
    #
    # @param [#each] *a an Enumerable edges set
    # @return [Graph] `self`
    def add_edges!(*a)
      a.each { |edge| add_edge!(edge) }
      self
    end
    alias add_arcs! add_edges!

    # Same as {GraphBuilder#add_egdes! add_edges!} but works on a copy of the receiver.
    #
    # @param [#each] *a an Enumerable edges set
    # @return [Graph] a modified copy of `self`
    def add_edges(*a)
      x = self.class.new(self)
      x.add_edges!(*a)
      self
    end
    alias add_arcs add_edges

    # Removes all vertices mentionned in the specified Enumerable from the graph.
    #
    # The process relies on {GraphBuilder#remove_vertex! remove_vertex!}.
    #
    # @param [#each] *a an Enumerable vertices set
    # @return [Graph] `self`
    def remove_vertices!(*a)
      a.each { |v| remove_vertex! v }
    end
    alias delete_vertices! remove_vertices!

    # Same as {GraphBuilder#remove_vertices! remove_vertices!} but works on a copy of the receiver.
    #
    # @param [#each] *a a vertex Enumerable set
    # @return [Graph] a modified copy of `self`
    def remove_vertices(*a)
      x = self.class.new(self)
      x.remove_vertices(*a)
    end
    alias delete_vertices remove_vertices

    # Removes all edges mentionned in the specified Enumerable from the graph.
    #
    # The process relies on {GraphBuilder#remove_edges! remove_edges!}.
    #
    # @param [#each] *a an Enumerable edges set
    # @return [Graph] `self`
    def remove_edges!(*a)
      a.each { |e| remove_edge! e }
    end
    alias remove_arcs! remove_edges!
    alias delete_edges! remove_edges!
    alias delete_arcs! remove_edges!

    # Same as {GraphBuilder#remove_edges! remove_edges!} but works on a copy of the receiver.
    #
    # @param [#each] *a an Enumerable edges set
    # @return [Graph] a modified copy of `self`
    def remove_edges(*a)
      x = self.class.new(self)
      x.remove_edges!(*a)
    end
    alias remove_arcs remove_edges
    alias delete_edges remove_edges
    alias delete_arcs remove_edges

    # Executes the given block for each vertex. It allows for mixing Enumerable in.
    def each(&block)
      vertices.each(&block)
    end

    # Returns true if the specified vertex belongs to the graph.
    #
    # This is a default implementation that is of O(n) average complexity.
    # If a subclass uses a hash to store vertices, then this can be
    # made into an O(1) average complexity operation.
    #
    # @param [vertex] v
    # @return [Boolean]
    def vertex?(v)
      vertices.include?(v)
    end
    alias has_vertex? vertex?
    # TODO: (has_)vertices?

    # Returns true if u or (u,v) is an {Edge edge} of the graph.
    #
    # @overload edge?(a)
    #   @param [Arc, Edge] a
    # @overload edge?(u, v)
    #   @param [vertex] u
    #   @param [vertex] v
    # @return [Boolean]
    def edge?(*args)
      edges.include?(edge_convert(*args))
    end
    alias arc? edge?
    alias has_edge? edge?
    alias has_arc? edge?

    # Tests two objects to see if they are adjacent.
    #
    # Note that in this method, one is primarily concerned with finding
    # all adjacent objects in a graph to a given object. The concern is primarily on seeing
    # if two objects touch. For two vertexes, any edge between the two will usually do, but
    # the direction can be specified if needed.
    #
    # @param [vertex] source
    # @param [vertex] target
    # @param [Symbol] direction (:all) constraint on the direction of adjacency; may be either `:in`, `:out` or `:all`
    def adjacent?(source, target, direction = :all)
      if source.is_a? Plexus::Arc
        raise NoArcError unless edge? source
        if target.is_a? Plexus::Arc
          raise NoArcError unless edge? target
          (direction != :out and source.source == target.target) or (direction != :in and source.target == target.source)
        else
          raise NoVertexError unless vertex? target
          (direction != :out and source.source == target)  or (direction != :in and source.target == target)
        end
      else
        raise NoVertexError unless vertex? source
        if target.is_a? Plexus::Arc
          raise NoArcError unless edge? target
          (direction != :out and source == target.target) or (direction != :in and source == target.source)
        else
          raise NoVertexError unless vertex? target
          (direction != :out and edge?(target,source)) or (direction != :in and edge?(source,target))
        end
      end
    end

    # Is the graph connected?
    #
    # A graph is called connected if every pair of distinct vertices in the graph
    # can be connected through some path. The exact definition depends on whether
    # the graph is directed or not, hence this method should overriden in specific
    # implementations.
    #
    # This methods implements a lazy routine using the internal vertices hash.
    # If you ever want to check connectivity state using a bfs/dfs algorithm, use
    # the `:algo => :bfs` or `:dfs` option.
    #
    # @return [Boolean] `true` if the graph is connected, `false` otherwise
    def connected?(options = {})
      options = options.reverse_merge! :algo => :bfs
      if options[:algo] == (:bfs || :dfs)
        num_nodes = 0
        send(options[:algo]) { |n| num_nodes += 1 }
        return num_nodes == @vertex_dict.size
      else
        !@vertex_dict.collect { |v| degree(v) > 0 }.any? { |check| check == false }
      end
    end
    # TODO: do it!
    # TODO: for directed graphs, add weakly_connected? and strongly_connected? (aliased as strong?)
    # TODO: in the context of vertices/Arc, add connected_vertices? and disconnected_vertices?
    # TODO: maybe implement some routine which would compute cuts and connectivity? tricky though,
    #       but would be useful (k_connected?(k))

    # Returns true if the graph has no vertex.
    #
    # @return [Boolean]
    def empty?
      vertices.size.zero?
    end

    # Returns true if the given object is a vertex or an {Arc arc} of the graph.
    #
    # @param [vertex, Arc] x
    def include?(x)
      x.is_a?(Plexus::Arc) ? edge?(x) : vertex?(x)
    end
    alias has? include?

    # Returns the neighborhood of the given vertex or {Arc arc}.
    #
    # This is equivalent to {GraphBuilder#adjacent adjacent}, but the type is based on the
    # type of the specified object.
    #
    # @param [vertex, Arc] x
    # @param [Symbol] direction (:all) can be either `:all`, `:in` or `:out`
    def neighborhood(x, direction = :all)
      adjacent(x, :direction => direction, :type => ((x.is_a? Plexus::Arc) ? :edges : :vertices ))
    end

    # Union of all neighborhoods of vertices (or edges) in the Enumerable x minus the contents of x.
    #
    # Definition taken from: Jorgen Bang-Jensen, Gregory Gutin, *Digraphs: Theory, Algorithms and Applications*, pg. 4
    #
    # @param [vertex] x
    # @param [Symbol] direction can be either `:all`, `:in` or `:out`
    def set_neighborhood(x, direction = :all)
      x.inject(Set.new) { |a,v| a.merge(neighborhood(v, direction))}.reject { |v2| x.include?(v2) }
    end

    # Union of all {GraphBuilder#set_neighborhood set_neighborhoods} reachable
    # among the specified edges.
    #
    # Definition taken from Jorgen Bang-Jensen, Gregory Gutin, *Digraphs:
    # Theory, Algorithms and Applications*, pg. 46
    #
    # @param [vertex] w
    # @param [Edges] p
    # @param [Symbol] direction can be `:all`, `:in`, or `:out`
    def closed_pth_neighborhood(w, p, direction = :all)
      if    p <= 0
        w
      elsif p == 1
        (w + set_neighborhood(w, direction)).uniq
      else
        n = set_neighborhood(w, direction)
        (w + n + closed_pth_neighborhood(n, p-1, direction)).uniq
      end
    end

    # Returns the neighboorhoods reachable in a certain amount of steps from
    # every vertex (or edge) in the specified Enumerable.
    #
    # Definition taken from Jorgen Bang-Jensen, Gregory Gutin, _Digraphs:
    # Theory, Algorithms and Applications_, pg. 46
    #
    # @param [Enumerable] x
    # @param [Integer] p number of steps to perform
    # @param [Symbol] direction can be `:all`, `:in`, or `:out`
    def open_pth_neighborhood(x, p, direction = :all)
      if    p <= 0
        x
      elsif p == 1
        set_neighborhood(x,direction)
      else
        set_neighborhood(open_pth_neighborhood(x, p-1, direction), direction) -
        closed_pth_neighborhood(x, p-1, direction)
      end
    end

    # Returns the number of out-edges (for directed graphs) or the number of
    # incident edges (for undirected graphs) of the specified vertex.
    #
    # @param [vertex] v
    # @return [Integer] number of matching edges
    def out_degree(v)
      adjacent(v, :direction => :out).size
    end

    # Returns the number of in-edges (for directed graphs) or the number of
    # incident edges (for undirected graphs) of the specified vertex
    #
    # @param [vertex] v
    # @return [Integer] number of matching edges
    def in_degree(v)
      adjacent(v, :direction => :in).size
    end

    # Returns the sum of the number in and out edges for the specified vertex.
    #
    # @param [vertex] v
    # @return [Integer] degree
    def degree(v)
      in_degree(v) + out_degree(v)
    end

    # Minimum in-degree of the graph.
    #
    # @return [Integer, nil] returns `nil` if the graph is empty
    def min_in_degree
      return nil if to_a.empty?
      to_a.map { |v| in_degree(v) }.min
    end

    # Minimum out-degree of the graph.
    #
    # @return [Integer, nil] returns `nil` if the graph is empty
    def min_out_degree
      return nil if to_a.empty?
      to_a.map {|v| out_degree(v)}.min
    end

    # Minimum degree of all vertexes of the graph.
    #
    # @return [Integer] `min` between {GraphBuilder#min_in_degree min_in_degree}
    #   and {GraphBuilder#min_out_degree max_out_degree}
    def min_degree
      [min_in_degree, min_out_degree].min
    end

    # Maximum in-degree of the graph.
    #
    # @return [Integer, nil] returns `nil` if the graph is empty
    def max_in_degree
      return nil if to_a.empty?
      vertices.map { |v| in_degree(v)}.max
    end

    # Maximum out-degree of the graph.
    #
    # @return [Integer, nil] returns nil if the graph is empty
    def max_out_degree
      return nil if to_a.empty?
      vertices.map { |v| out_degree(v)}.max
    end

    # Maximum degree of all vertexes of the graph.
    #
    # @return [Integer] `max` between {GraphBuilder#max_in_degree max_in_degree}
    #   and {GraphBuilder#max_out_degree max_out_degree}
    def max_degree
      [max_in_degree, max_out_degree].max
    end

    # Is the graph regular, that is are its min degree and max degree equal?
    #
    # @return [Boolean]
    def regular?
      min_degree == max_degree
    end

    # Number of vertices.
    #
    # @return [Integer]
    def size
      vertices.size
    end
    alias num_vertices size
    alias number_of_vertices size

    # Number of vertices.
    #
    # @return [Integer]
    def num_vertices
      vertices.size
    end
    alias number_of_vertices num_vertices

    # Number of edges.
    #
    # @return [Integer]
    def num_edges
      edges.size
    end
    alias number_of_edges num_edges

    # Utility method to show a string representation of the edges of the graph.
    #def to_s
      #edges.to_s
    #end

    # Equality is defined to be same set of edges and directed?
    def eql?(g)
      return false unless g.is_a? Plexus::Graph

      (directed?     == g.directed?)     and
      (vertices.sort == g.vertices.sort) and
      (edges.sort    == g.edges.sort)
    end
    alias == eql?

    # Merges another graph into the receiver.
    #
    # @param [Graph] other the graph to merge in
    # @return [Graph] `self`
    def merge(other)
      other.vertices.each { |v| add_vertex!(v)       }
      other.edges.each    { |e| add_edge!(e)         }
      other.edges.each    { |e| add_edge!(e.reverse) } if directed? and !other.directed?
      self
    end

    # A synonym for {GraphBuilder#merge merge}, but doesn't modify the current graph.
    #
    # @param [Graph, Arc] other
    # @return [Graph] a new graph
    def +(other)
      result = self.class.new(self)
      case other
      when Plexus::Graph
        result.merge(other)
      when Plexus::Arc
        result.add_edge!(other)
      else
        result.add_vertex!(other)
      end
    end

    # Removes all vertices in the specified graph.
    #
    # @param [Graph, Arc] other
    # @return [Graph]
    def -(other)
      case other
      when Plexus::Graph
        induced_subgraph(vertices - other.vertices)
      when Plexus::Arc
        self.class.new(self).remove_edge!(other)
      else
        self.class.new(self).remove_vertex!(other)
      end
    end

    # A synonym for {AdjacencyGraphBuilder#add_edge! add_edge!}.
    def <<(edge)
      add_edge!(edge)
    end

    # Computes the complement of the current graph.
    #
    # @return [Graph]
    def complement
      vertices.inject(self.class.new) do |a,v|
        a.add_vertex!(v)
        vertices.each { |v2| a.add_edge!(v, v2) unless edge?(v, v2) }; a
      end
    end

    # Given an array of vertices, computes the induced subgraph.
    #
    # @param [Array(vertex)] v
    # @return [Graph]
    def induced_subgraph(v)
      edges.inject(self.class.new) do |a,e|
        (v.include?(e.source) and v.include?(e.target)) ? (a << e) : a
      end
    end

    def inspect
      ## FIXME: broken, it's not updated. The issue's not with inspect, but it's worth mentionning here.
      ## Example:
      ##     dg = Digraph[1,2, 2,3, 2,4, 4,5, 6,4, 1,6]
      ##     dg.add_vertices! 1, 5, "yosh"
      ##     # => Plexus::Digraph[Plexus::Arc[1,2,nil], Plexus::Arc[1,6,nil], Plexus::Arc[2,3,nil], Plexus::Arc[2,4,nil], Plexus::Arc[4,5,nil], Plexus::Arc[6,4,nil]]
      ##     dg.vertex?("yosh")
      ##     # => true
      ##     dg
      ##     # =>Plexus::Digraph[Plexus::Arc[1,2,nil], Plexus::Arc[1,6,nil], Plexus::Arc[2,3,nil], Plexus::Arc[2,4,nil], Plexus::Arc[4,5,nil], Plexus::Arc[6,4,nil]]
      ## the new vertex doesn't show up.
      ## Actually this version of inspect is far too verbose IMO :)
      l = vertices.select { |v| self[v]}.map { |u| "vertex_label_set(#{u.inspect}, #{self[u].inspect})"}.join('.')
      self.class.to_s + '[' + edges.map {|e| e.inspect}.join(', ') + ']' + (l && l != '' ? '.'+l : '')
    end

    private

    # ?
    def edge_convert(*args)
      args[0].is_a?(Plexus::Arc) ? args[0] : edge_class[*args]
    end
  end
end
