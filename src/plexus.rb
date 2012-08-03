#--
# Copyright (c) 2006 Shawn Patrick Garbett
# Copyright (c) 2002,2004,2005 by Horst Duchene
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice(s),
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#     * Neither the name of the Shawn Garbett nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#++

require 'set'

module Plexus
  # Plexus internals: graph builders and additionnal behaviors
  autoload :GraphBuilder,                 'plexus/graph'
  autoload :AdjacencyGraphBuilder,        'plexus/adjacency_graph'

  autoload :DirectedGraphBuilder,         'plexus/directed_graph'
  autoload :DigraphBuilder,               'plexus/directed_graph'
  autoload :DirectedPseudoGraphBuilder,   'plexus/directed_graph'
  autoload :DirectedMultiGraphBuilder,    'plexus/directed_graph'

  autoload :UndirectedGraphBuilder,       'plexus/undirected_graph'
  autoload :UndirectedPseudoGraphBuilder, 'plexus/undirected_graph'
  autoload :UndirectedMultiGraphBuilder,  'plexus/undirected_graph'

  autoload :Arc,                          'plexus/arc'
  autoload :ArcNumber,                    'plexus/arc_number'
  autoload :Biconnected,                  'plexus/biconnected'
  autoload :ChinesePostman,               'plexus/chinese_postman'
  autoload :Common,                       'plexus/common'
  autoload :Comparability,                'plexus/comparability'

  autoload :Dot,                          'plexus/dot'
  autoload :Edge,                         'plexus/edge'
  autoload :Labels,                       'plexus/labels'
  autoload :MaximumFlow,                  'plexus/maximum_flow'
  #autoload :Rdot,                        'plexus/dot'
  autoload :Search,                       'plexus/search'
  autoload :StrongComponents,             'plexus/strong_components'

  # Plexus classes
  autoload :AdjacencyGraph,               'plexus/classes/graph_classes'
  autoload :DirectedGraph,                'plexus/classes/graph_classes'
  autoload :Digraph,                      'plexus/classes/graph_classes'
  autoload :DirectedPseudoGraph,          'plexus/classes/graph_classes'
  autoload :DirectedMultiGraph,           'plexus/classes/graph_classes'
  autoload :UndirectedGraph,              'plexus/classes/graph_classes'
  autoload :UndirectedPseudoGraph,        'plexus/classes/graph_classes'
  autoload :UndirectedMultiGraph,         'plexus/classes/graph_classes'

  # ruby stdlib extensions
  require './plexus/ext'
  # ruby 1.8.x/1.9.x compatibility
  require './plexus/ruby_compatibility'
end

# Because we are bundled in OSMonitor!
$:.unshift File.dirname(__FILE__)

# Vendored libraries

require 'pathname'
path = Pathname.new(__FILE__)
$LOAD_PATH.unshift(path + '../../vendor') # http://ruby.brian-amberg.de/priority-queue/
$LOAD_PATH.unshift(path + '../../vendor/priority-queue/lib')

#require 'rdot'
require 'facets/hash'

require 'priority_queue/ruby_priority_queue'
PriorityQueue = RubyPriorityQueue

