module Plexus

  # This module provides the basic routines needed to implement the specialized builders:
  # {DigraphBuilder}, {UndirectedGraphBuilder}, {DirectedPseudoGraphBuilder},
  # {UndirectedPseudoGraphBuilder}, {DirectedMultiGraphBuilder} and {UndirectedMultiGraphBuilder}
  # modules, each of them streamlining {AdjacencyGraphBuilder}'s behavior. Those
  # implementations rely on the {GraphBuilder}.
  module AdjacencyGraphBuilder

    # Defines a useful `push` -> `add` alias for arrays.
    class ArrayWithAdd < Array
      alias add push
    end

    # This method is called by the specialized implementations
    # upon graph creation.
    #
    # Initialization parameters can include:
    #
    # * an array of edges to add
    # * one or several graphs to copy (will be merged if multiple)
    # * `:parallel_edges` denotes that duplicate edges are allowed
    # * `:loops denotes` that loops are allowed
    #
    # @param *params [Hash] the initialization parameters
    #
    def implementation_initialize(*params)
      @vertex_dict = Hash.new
      clear_all_labels

      # FIXME: could definitely make use of the activesupport helper
      # extract_options! and facets' reverse_merge! technique
      # to handle parameters
      args = (params.pop if params.last.is_a? Hash) || {}

      # Basic configuration of adjacency.
      @allow_loops    = args[:loops]          || false
      @parallel_edges = args[:parallel_edges] || false
      @edgelist_class = @parallel_edges ? ArrayWithAdd : Set
      if @parallel_edges
        @edge_number      = Hash.new
        @next_edge_number = 0
      end

      # Copy any given graph into this graph.
      params.select { |p| p.is_a? Plexus::GraphBuilder }.each do |g|
        g.edges.each do |e|
          add_edge!(e)
          edge_label_set(e, edge_label(e)) if edge_label(e)
        end
        g.vertices.each do |v|
          add_vertex!(v)
          vertex_label_set(v, vertex_label(v)) if vertex_label(v)
        end
      end

      # Add all array edges specified.
      params.select { |p| p.is_a? Array }.each do |a|
        0.step(a.size-1, 2) { |i| add_edge!(a[i], a[i+1]) }
      end
    end

    # Returns true if v is a vertex of this Graph
    # (an "O(1)" implementation of `vertex?`).
    #
    # @param [vertex] v
    # @return [Boolean]
    def vertex?(v)
      @vertex_dict.has_key?(v)
    end

    # Returns true if [u,v] or u is an {Arc}
    # (an "O(1)" implementation of `edge?`).
    #
    # @param [vertex] u
    # @param [vertex] v (nil)
    # @return [Boolean]
    def edge?(u, v = nil)
      u, v = u.source, u.target if u.is_a? Plexus::Arc
      vertex?(u) and @vertex_dict[u].include?(v)
    end

    # Adds a vertex to the graph with an optional label.
    #
    # @param [vertex(Object)] vertex any kind of Object can act as a vertex
    # @param [#to_s] label (nil)
    def add_vertex!(vertex, label = nil)
      @vertex_dict[vertex] ||= @edgelist_class.new
      self[vertex] = label if label
      self
    end

    # Adds an edge to the graph.
    #
    # Can be called in two basic ways, label is optional:
    # @overload add_edge!(arc)
    #   Using an explicit {Arc}
    #   @param [Arc] arc an {Arc}[source, target, label = nil] object
    #   @return [AdjacencyGraph] `self`
    # @overload add_edge!(source, target, label = nil)
    #   Using vertices to define an arc implicitly
    #   @param [vertex] u
    #   @param [vertex] v (nil)
    #   @param [Label] l (nil)
    #   @param [Integer] n (nil) {Arc arc} number of `(u, v)` (if `nil` and if `u`
    #     has an {ArcNumber}, then it will be used)
    #   @return [AdjacencyGraph] `self`
    #
    def add_edge!(u, v = nil, l = nil, n = nil)
      n = u.number if u.class.include? ArcNumber and n.nil?
      u, v, l = u.source, u.target, u.label if u.is_a? Plexus::Arc

      return self if !@allow_loops && u == v

      n = (@next_edge_number += 1) unless n if @parallel_edges
      add_vertex!(u)
      add_vertex!(v)
      @vertex_dict[u].add(v)
      (@edge_number[u] ||= @edgelist_class.new).add(n) if @parallel_edges

      unless directed?
        @vertex_dict[v].add(u)
        (@edge_number[v] ||= @edgelist_class.new).add(n) if @parallel_edges
      end

      self[n ? edge_class[u,v,n] : edge_class[u,v]] = l if l
      self
    end

    # Removes a given vertex from the graph.
    #
    # @param [vertex] v
    # @return [AdjacencyGraph] `self`
    def remove_vertex!(v)
      # FIXME This is broken for multi graphs
      @vertex_dict.delete(v)
      @vertex_dict.each_value { |adjList| adjList.delete(v) }
      @vertex_dict.keys.each do |u|
        delete_label(edge_class[u,v])
        delete_label(edge_class[v,u])
      end
      delete_label(v)
      self
    end

    # Removes an edge from the graph.
    #
    # Can be called with both source and target as vertex,
    # or with source and object of {Plexus::Arc} derivation.
    #
    # @overload remove_edge!(a)
    #   @param [Plexus::Arc] a
    #   @return [AdjacencyGraph] `self`
    #   @raise [ArgumentError] if parallel edges are enabled
    # @overload remove_edge!(u, v)
    #   @param [vertex] u
    #   @param [vertex] v
    #   @return [AdjacencyGraph] `self`
    #   @raise [ArgumentError] if parallel edges are enabled and the {ArcNumber} of `u` is zero
    def remove_edge!(u, v = nil)
      unless u.is_a? Plexus::Arc
        raise ArgumentError if @parallel_edges
        u = edge_class[u,v]
      end
      raise ArgumentError if @parallel_edges and (u.number || 0) == 0
      return self unless @vertex_dict[u.source] # It doesn't exist
      delete_label(u) # Get rid of label
      if @parallel_edges
        index = @edge_number[u.source].index(u.number)
        raise NoArcError unless index
        @vertex_dict[u.source].delete_at(index)
        @edge_number[u.source].delete_at(index)
      else
        @vertex_dict[u.source].delete(u.target)
      end
      self
    end

    # Returns an array of vertices that the graph has.
    #
    # @return [Array] graph's vertices
    def vertices
      @vertex_dict.keys
    end

    # Returns an array of edges, most likely of class {Arc} or {Edge} depending
    # upon the type of graph.
    #
    # @return [Array]
    def edges
      @vertex_dict.keys.inject(Set.new) do |a,v|
        if @parallel_edges and @edge_number[v]
          @vertex_dict[v].zip(@edge_number[v]).each do |w|
            s, t, n = v, w[0], w[1]
            a.add(edge_class[s, t, n, edge_label(s, t, n)])
          end
        else
          @vertex_dict[v].each do |w|
            a.add(edge_class[v, w, edge_label(v, w)])
          end
        end
        a
      end.to_a
    end

    # FIXME, EFFED UP (but why?)
    #
    # @fixme
    def adjacent(x, options = {})
      options[:direction] ||= :out

      if !x.is_a?(Plexus::Arc) and (options[:direction] == :out || !directed?)
        if options[:type] == :edges
          i = -1
          @parallel_edges ?
            @vertex_dict[x].map { |v| e = edge_class[x, v, @edge_number[x][i+=1]]; e.label = self[e]; e } :
            @vertex_dict[x].map { |v| e = edge_class[x, v];  e.label = self[e]; e }
        else
          @vertex_dict[x].to_a
        end
      else
        graph_adjacent(x,options)
      end
    end
  end
end
