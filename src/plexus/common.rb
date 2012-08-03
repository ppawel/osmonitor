module Plexus

  # This class defines a cycle graph of size n.
  # This is easily done by using the base Graph
  # class and implemeting the minimum methods needed to
  # make it work. This is a good example to look
  # at for making one's own graph classes.
  module CycleBuilder
    def initialize(n)
      @size = n;
    end

    def directed?
      false
    end

    def vertices
      (1..@size).to_a
    end

    def vertex?(v)
      v > 0 and v <= @size
    end

    def edge?(u,v = nil)
      u, v = [u.source, v.target] if u.is_a? Plexus::Arc
      vertex?(u) && vertex?(v) && ((v-u == 1) or (u == @size && v = 1))
    end

    def edges
      Array.new(@size) { |i| Plexus::Edge[i+1, (i+1) == @size ? 1 : i+2]}
    end
  end # CycleBuilder

  # This class defines a complete graph of size n.
  # This is easily done by using the base Graph
  # class and implemeting the minimum methods needed to
  # make it work. This is a good example to look
  # at for making one's own graph classes.
  module CompleteBuilder
    include CycleBuilder

    def initialize(n)
      @size = n
      @edges = nil
    end

    def edges
      return @edges if @edges      # cache edges
      @edges = []
      @size.times do |u|
        @size.times { |v| @edges << Plexus::Edge[u+1, v+1]}
      end
      @edges
    end

    def edge?(u, v = nil)
      u, v = [u.source, v.target] if u.kind_of? Plexus::Arc
      vertex?(u) && vertex?(v)
    end
  end # CompleteBuilder

end # Plexus
