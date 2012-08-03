module Plexus
  module Dot

    #FIXME: don't really understood where we stand with the dot generators.
    # RDoc ships with a dot.rb which seems pretty efficient.
    # Are these helpers still needed, and if not, how should we replace them?

    # Creates a DOT::DOTDigraph for directed graphs or a DOT::DOTSubgraph for
    # undirected graphs.
    #
    # @param [Hash] params can contain any graph property specified in
    #   rdot.rb. If an edge or vertex label is a kind of Hash, then the keys
    #   which match dot properties will be used as well.
    # @return [DOT::DOTDigraph, DOT::DOTSubgraph]
    def to_dot_graph(params = {})
      params['name'] ||= self.class.name.gsub(/:/, '_')
      fontsize         = params['fontsize'] ? params['fontsize'] : '8'
      graph            = (directed? ? DOT::DOTDigraph : DOT::DOTSubgraph).new(params)
      edge_klass       =  directed? ? DOT::DOTDirectedArc : DOT::DOTArc

      vertices.each do |v|
        name = v.to_s || v.__id__.to_s
        name = name.dup.gsub(/"/, "'")

        params = { 'name'     => '"'+ name +'"',
                   'fontsize' => fontsize,
                   'label'    => name}

        v_label = vertex_label(v)
        params.merge!(v_label) if v_label and v_label.kind_of? Hash

        graph << DOT::DOTNode.new(params)
      end

      edges.each do |e|
        if e.source.to_s.nil?
          source_label = e.source.__id__.to_s
        else
          source_label = e.source.to_s.dup
        end

        if e.target.to_s.nil?
          target_label = e.target.__id__.to_s
        else
          target_label = e.target.to_s.dup
        end

        source_label.gsub!(/"/, "'")
        target_label.gsub!(/"/, "'")

        params = { 'from'     => '"'+ source_label + '"',
                   'to'       => '"'+ target_label + '"',
                   'fontsize' => fontsize }

        e_label = edge_label(e)
        params.merge!(e_label) if e_label and e_label.kind_of? Hash

        graph << edge_klass.new(params)
      end

      graph
    end

    # Output the dot format as a string
    def to_dot(params = {})
      to_dot_graph(params).to_s
    end

    # Call +dotty+ for the graph which is written to the file 'graph.dot'
    # in the # current directory.
    def dotty(params = {}, dotfile = 'graph.dot')
      File.open(dotfile, 'w') {|f| f << to_dot(params) }
      system('dotty', dotfile)
    end

    # Use +dot+ to create a graphical representation of the graph. Returns the
    # filename of the graphics file.
    def write_to_graphic_file(fmt = 'png', dotfile = 'graph')
      src = dotfile + '.dot'
      dot = dotfile + '.' + fmt

      # DOT::DOTSubgraph creates subgraphs, but that's broken.
      buffer = self.to_dot
      buffer.gsub!(/^subgraph/, "graph")

      File.open(src, 'w') {|f| f << buffer << "\n"}
      system( "dot -T#{fmt} #{src} -o #{dot}" )

      dot
    end
    alias as_dot_graphic write_to_graphic_file

  end # Dot
end # module Plexus
