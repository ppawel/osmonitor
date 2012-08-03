module Plexus
  module DirectedGraphBuilder

    # This module provides algorithms computing distance between
    # vertices.
    module Distance
      
      # Shortest path computation.
      #
      # From: Jorgen Band-Jensen and Gregory Gutin,
      # [*Digraphs: Theory, Algorithms and Applications*](http://www.springer.com/mathematics/numbers/book/978-1-84800-997-4), pg. 53-54.
      # Complexity `O(n+m)`.
      #
      # Requires the graph to be acyclic. If the graph is not acyclic,
      # then see {Distance#dijkstras_algorithm} or {Distance#bellman_ford_moore}
      # for possible solutions.
      #
      # @param [vertex] start the starting vertex 
      # @param [Proc, #[]] weight can be a `Proc`, or anything else accessed using the `[]`
      #   operator. If not a `Proc`, and if no label accessible through `[]`, it will
      #   default to using the value stored in the label for the {Arc}. If a `Proc`, it will 
      #   pass the edge to the proc and use the resulting value.
      # @param [Integer] zero used for math systems with a different definition of zero
      #
      # @return [Hash] a hash with the key being a vertex and the value being the
      # distance. A missing vertex from the hash is equivalent to an infinite distance.
      def shortest_path(start, weight = nil, zero = 0)
        dist = { start => zero }
        path = {}
        topsort(start) do |vi|
          next if vi == start
          dist[vi], path[vi] = adjacent(vi, :direction => :in).map do |vj|
            [dist[vj] + cost(vj,vi,weight), vj] 
          end.min { |a,b| a[0] <=> b[0]}
        end; 
        dist.keys.size == vertices.size ? [dist, path] : nil
      end   
      
      # Finds the distance from a given vertex in a weighted digraph
      # to the rest of the vertices, provided all the weights of arcs
      # are non-negative.
      #
      # If negative arcs exist in the graph, two basic options exist:
      #
      # * modify all weights to be positive using an offset (temporary at least)
      # * use the {Distance#bellman_ford_moore} algorithm.
      #
      # Also, if the graph is acyclic, use the {Distance#shortest_path algorithm}.
      #
      # From: Jorgen Band-Jensen and Gregory Gutin,
      # [*Digraphs: Theory, Algorithms and Applications*](http://www.springer.com/mathematics/numbers/book/978-1-84800-997-4), pg. 53-54.
      #
      # Complexity `O(n*log(n) + m)`.
      # 
      # @param [vertex] s
      # @param [Proc, #[]] weight can be a `Proc`, or anything else accessed using the `[]`
      #   operator. If not a `Proc`, and if no label accessible through `[]`, it will
      #   default to using the value stored in the label for the {Arc}. If a `Proc`, it will 
      #   pass the edge to the proc and use the resulting value.
      # @param [Integer] zero used for math systems with a different definition of zero
      # @return [Hash] a hash with the key being a vertex and the value being the
      #   distance. A missing vertex from the hash is equivalent to an infinite distance.
      def dijkstras_algorithm(s, weight = nil, zero = 0)
        q = vertices; distance = { s => zero }
        path = {}
        while not q.empty?
          v = (q & distance.keys).inject(nil) { |a,k| (!a.nil?) && (distance[a] < distance[k]) ? a : k} 
          q.delete(v)
          (q & adjacent(v)).each do |u|
            c = cost(v, u, weight)
            if distance[u].nil? or distance[u] > (c + distance[v])
              distance[u] = c + distance[v]
              path[u] = v
            end
          end
        end
        [distance, path]
      end

      # Finds the distances from a given vertex in a weighted digraph
      # to the rest of the vertices, provided the graph has no negative cycle.
      #
      # If no negative weights exist, then {Distance#dijkstras_algorithm} is more
      # efficient in time and space. Also, if the graph is acyclic, use the
      # {Distance#shortest_path} algorithm.
      #
      # From: Jorgen Band-Jensen and Gregory Gutin,
      # [*Digraphs: Theory, Algorithms and Applications*](http://www.springer.com/mathematics/numbers/book/978-1-84800-997-4), pg. 56-58..
      #
      # Complexity `O(nm)`.
      #
      # @param [vertex] s
      # @param [Proc, #[]] weight can be a `Proc`, or anything else accessed using the `[]`
      #   operator. If not a `Proc`, and if no label accessible through `[]`, it will
      #   default to using the value stored in the label for the {Arc}. If a `Proc`, it will 
      #   pass the edge to the proc and use the resulting value.
      # @param [Integer] zero used for math systems with a different definition of zero
      # @return [Hash] a hash with the key being a vertex and the value being the
      #   distance. A missing vertex from the hash is equivalent to an infinite distance.
      def bellman_ford_moore(start, weight = nil, zero = 0)
        distance = { start => zero }
        path = {}
        2.upto(vertices.size) do
          edges.each do |e|
            u, v = e[0], e[1]
            unless distance[u].nil?
              c = cost(u, v, weight) + distance[u]
              if distance[v].nil? or c < distance[v]
                distance[v] = c
                path[v] = u
              end 
            end        
          end
        end
        [distance, path]
      end
      
      # Uses the Floyd-Warshall algorithm to efficiently find
      # and record shortest paths while establishing at the same time
      # the costs for all vertices in a graph.
      #
      # See S.Skiena, *The Algorithm Design Manual*, Springer Verlag, 1998 for more details.
      #
      # O(n^3) complexity in time.
      #  
      # @param [Proc, nil] weight specifies how an edge weight is determined.
      #   If it's a `Proc`, the {Arc} is passed to it; if it's `nil`, it will just use
      #   the value in the label for the Arc; otherwise the weight is
      #   determined by applying the `[]` operator to the value in the 
      #   label for the {Arc}.
      # @param [Integer] zero defines the zero value in the math system used.
      #   This allows for no assumptions to be made about the math system and
      #   fully functional duck typing.
      # @return [Array(matrice, matrice, Hash)] a pair of matrices and a hash of delta values. 
      #   The matrices will be indexed by two vertices and are implemented as a Hash of Hashes.
      #   The first matrix is the cost, the second matrix is the shortest path spanning tree.
      #   The delta (difference of number of in-edges and out-edges) is indexed by vertex.
      def floyd_warshall(weight = nil, zero = 0)
        c     = Hash.new { |h,k| h[k] = Hash.new }
        path  = Hash.new { |h,k| h[k] = Hash.new }
        delta = Hash.new { |h,k| h[k] = 0 }
        edges.each do |e| 
          delta[e.source] += 1
          delta[e.target] -= 1
          path[e.source][e.target] = e.target      
          c[e.source][e.target] = cost(e, weight)
        end
        vertices.each do |k|
          vertices.each do |i|
            if c[i][k]
              vertices.each do |j|
                if c[k][j] && 
                    (c[i][j].nil? or c[i][j] > (c[i][k] + c[k][j]))
                  path[i][j] = path[i][k]
                  c[i][j] = c[i][k] + c[k][j]
                  return nil if i == j and c[i][j] < zero
                end
              end
            end  
          end
        end
        [c, path, delta]
      end

    end # Distance
  end # DirectedGraph
end # Plexus
