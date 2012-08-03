module Plexus
  module UndirectedGraphBuilder
    autoload :Algorithms, "plexus/undirected_graph/algorithms"

    include Plexus::GraphBuilder
    extends_host

    module ClassMethods
      def [](*a)
        self.new.from_array(*a)
      end
    end

    def initialize(*params)
      args = (params.pop if params.last.kind_of? Hash) || {}
      args[:algorithmic_category] = Plexus::UndirectedGraphBuilder::Algorithms
      super *(params << args)
    end
  end

  # This is a Digraph that allows for parallel edges, but does not allow loops.
  module UndirectedPseudoGraphBuilder
    include UndirectedGraphBuilder
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

  # This is a Digraph that allows for parallel edges and loops.
  module UndirectedMultiGraphBuilder
    include UndirectedPseudoGraphBuilder
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
