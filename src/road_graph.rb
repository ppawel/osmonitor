require './model'


class RoadGraph
  attr_accessor :graph
  
  def initialize
    self.graph = Plexus::Digraph.new
  end
end
