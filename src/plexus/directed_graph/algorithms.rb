module Plexus
  # Digraph is a directed graph which is a finite set of vertices
  # and a finite set of edges connecting vertices. It cannot contain parallel
  # edges going from the same source vertex to the same target. It also
  # cannot contain loops, i.e. edges that go have the same vertex for source
  # and target.
  #
  # DirectedPseudoGraph is a class that allows for parallel edges, and
  # DirectedMultiGraph is a class that allows for parallel edges and loops
  # as well.
  module DirectedGraphBuilder
    module Algorithms
      include Search
      include StrongComponents
      include Distance
      include ChinesePostman

      # A directed graph is directed by definition.
      #
      # @return [Boolean] always true
      #
      def directed?
        true
      end

      # A digraph uses the Arc class for edges.
      #
      # @return [Plexus::MultiArc, Plexus::Arc] `Plexus::MultiArc` if the graph allows for parallel edges,
      #   `Plexus::Arc` otherwise.
      #
      def edge_class
        @parallel_edges ? Plexus::MultiArc : Plexus::Arc
      end

      # Reverse all edges in a graph.
      #
      # @return [DirectedGraph] a copy of the receiver for which the direction of edges has
      #   been inverted.
      #
      def reversal
        result = self.class.new
        edges.inject(result) { |a,e| a << e.reverse}
        vertices.each { |v| result.add_vertex!(v) unless result.vertex?(v) }
        result
      end

      # Check whether the graph is oriented or not.
      #
      # @return [Boolean]
      #
      def oriented?
        e = edges
        re = e.map { |x| x.reverse}
        not e.any? { |x| re.include?(x)}
      end

      # Balanced is the state when the out edges count is equal to the in edges count.
      #
      # @return [Boolean]
      #
      def balanced?(v)
        out_degree(v) == in_degree(v)
      end

      # Returns out_degree(v) - in_degree(v).
      #
      def delta(v)
        out_degree(v) - in_degree(v)
      end

      def community(node, direction, options = {:recursive => true})
        nodes, stack = {}, adjacent(node, :direction => direction)
        while n = stack.pop
          unless nodes[n.object_id] || node == n
            nodes[n.object_id] = n
            stack += adjacent(n, :direction => direction) if options[:recursive]
          end
        end
        nodes.values
      end

      def descendants(node, options = {:recursive => true})
        community(node, :out)
      end

      def ancestors(node, options = {:recursive => true})
        community(node, :in)
      end

      def family(node, options = {:recursive => true})
        community(node, :all)
      end
    end
  end
end
