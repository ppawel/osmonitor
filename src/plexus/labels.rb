module Plexus
  # This module add support for labels.
  #
  # The graph labeling process consist in assigning labels, traditionally represented
  # by integers, to the edges or vertices, or both, of a graph. Plexus recommands you
  # abide by this rule and do use integers as labels.
  #
  # Some algorithms can make use of labeling (sea {Plexus::Search} for instance).
  module Labels

    # Return a label for an edge or vertex.
    def [](u)
      (u.is_a? Plexus::Arc) ? edge_label(u) : vertex_label(u)
    end

    # Set a label for an edge or vertex.
    def []=(u, value)
      (u.is_a? Plexus::Arc) ? edge_label_set(u, value) : vertex_label_set(u, value)
    end

    # Delete a label entirely.
    def delete_label(u)
      (u.is_a? Plexus::Arc) ? edge_label_delete(u) : vertex_label_delete(u)
    end

    # Get the label for an edge.
    def vertex_label(v)
      vertex_label_dict[v]
    end

    # Set the label for an edge.
    def vertex_label_set(v, l)
      vertex_label_dict[v] = l
      self
    end

    # Get the label for an edge.
    def edge_label(u, v = nil, n = nil)
      u = edge_convert(u,v,n)
      edge_label_dict[u]
    end

    # Set the label for an edge.
    def edge_label_set(u, v = nil, l = nil, n = nil)
      u.is_a?(Plexus::Arc) ? l = v : u = edge_convert(u, v, n)
      edge_label_dict[u] = l
      self
    end

    # Delete all graph labels.
    def clear_all_labels
      @vertex_labels = {}
      @edge_labels = {}
    end

    # Delete an edge label.
    def edge_label_delete(u, v = nil, n = nil)
      u = edge_convert(u, v, n)
      edge_label_dict.delete(u)
    end

    # Delete a vertex label.
    def vertex_label_delete(v)
      vertex_label_dict.delete(v)
    end

    protected

    def vertex_label_dict
      @vertex_labels ||= {}
    end

    def edge_label_dict
      @edge_labels ||= {}
    end

    # A generic cost function.
    #
    # It either calls the `weight` function with an edge constructed from the
    # two specified nodes, or calls the `[]` operator of the label when given
    # a single value.
    #
    # If no weight value is specified, the label itself is treated as the cost value.
    #
    # Note: This function will not work for Pseudo or Multi graphs at present.
    # FIXME: Remove u,v interface to fix Pseudo Multi graph problems.
    def cost(u, v = nil, weight = nil)
      u.is_a?(Arc) ? weight = v : u = edge_class[u,v]
      case weight
      when Proc
        weight.call(u)
      when nil
        self[u]
      else
        self[u][weight]
      end
    end
    alias property cost # makes sense for property retrieval in general

    # A function to set properties specified by the user.
    def property_set(u, name, value)
      case name
      when Proc
        name.call(value)
      when nil
        self[u] = value
      else
        self[u][name] = value
      end
    end
  end
end
