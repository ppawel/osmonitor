module Plexus
  # A generic {GraphBuilder Graph} class you can inherit from.
  class Graph;                         include GraphBuilder;                 end

  # A generic {AdjacencyGraphBuilder AdjacencyGraph} class you can inherit from.
  class AdjacencyGraph < Graph;        include AdjacencyGraphBuilder;        end

  # A generic {DirectedGraphBuilder DirectedGraph} class you can inherit from.
  class DirectedGraph < Graph;         include DirectedGraphBuilder;         end

  # A generic {DigraphBuilder Digraph} class you can inherit from.
  class Digraph < Graph;               include DigraphBuilder;               end

  # A generic {DirectedPseudoGraphBuilder DirectedPseudoGraph} class you can inherit from.
  class DirectedPseudoGraph < Graph;   include DirectedPseudoGraphBuilder;   end

  # A generic {DirectedMultiGraphBuilder DirectedMultiGraph} class you can inherit from.
  class DirectedMultiGraph < Graph;    include DirectedMultiGraphBuilder;    end

  # A generic {UndirectedGraphBuilder UndirectedGraph} class you can inherit from.
  class UndirectedGraph < Graph;       include UndirectedGraphBuilder;       end

  # A generic {UndirectedPseudoGraphBuilder UndirectedPseudoGraph} class you can inherit from.
  class UndirectedPseudoGraph < Graph; include UndirectedPseudoGraphBuilder; end

  # A generic {UndirectedMultiGraphBuilder UndirectedMultiGraph} class you can inherit from.
  class UndirectedMultiGraph < Graph;  include UndirectedMultiGraphBuilder;  end
end
