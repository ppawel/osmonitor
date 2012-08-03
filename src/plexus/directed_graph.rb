module Plexus

  # This implements a directed graph which does not allow parallel
  # edges nor loops. That is, only one arc per nodes couple,
  # and only one parent per node. Mimics the typical hierarchy
  # structure.
  module DirectedGraphBuilder
    include GraphBuilder

    autoload :Algorithms, "plexus/directed_graph/algorithms"
    autoload :Distance,   "plexus/directed_graph/distance"

    # FIXME: DRY this snippet, I didn't find a clever way to
    # to dit though
    # TODO: well, extends_host_with do ... end would be cool,
    # using Module.new.module_eval(&block) in the helper.
    extends_host

    module ClassMethods
      def [](*a)
        self.new.from_array(*a)
      end
    end

    def initialize(*params)
      # FIXME/TODO: setting args to the hash or {} while getting rid
      # on the previous parameters prevents from passing another
      # graph to the initializer, so you cannot do things like:
      # UndirectedGraph.new(Digraph[1,2, 2,3, 2,4, 4,5, 6,4, 1,6])
      # As args must be a hash, if we're to allow such syntax,
      # we should provide a way to handle the graph as a hash
      # member.
      args = (params.pop if params.last.kind_of? Hash) || {}
      args[:algorithmic_category] = DirectedGraphBuilder::Algorithms
      super *(params << args)
    end
  end

  # DirectedGraph is just an alias for Digraph should one desire
  DigraphBuilder = DirectedGraphBuilder

  # This is a Digraph that allows for parallel edges, but does not
  # allow loops.
  module DirectedPseudoGraphBuilder
    include DirectedGraphBuilder
    extends_host

    module ClassMethods
      def [](*a)
        self.new.from_array(*a)
      end
    end

    def initialize(*params)
      args = (params.pop if params.last.kind_of? Hash) || {}
      args[:parallel_edges] = true
      super *(params << args)
    end
  end

  # This is a Digraph that allows for both parallel edges and loops.
  module DirectedMultiGraphBuilder
    include DirectedPseudoGraphBuilder
    extends_host

    module ClassMethods
      def [](*a)
        self.new.from_array(*a)
      end
    end

    def initialize(*params)
      args = (params.pop if params.last.kind_of? Hash) || {}
      args[:loops] = true
      super *(params << args)
    end
  end
end
