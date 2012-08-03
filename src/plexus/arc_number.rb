module Plexus
  # This module handles internal numbering of edges in order to differente between mutliple edges.
  module ArcNumber
    # Used to differentiate between mutli-edges
    attr_accessor :number

    def initialize(p_source, p_target, p_number, p_label = nil)
      self.number = p_number
      super(p_source, p_target, p_label)
    end

    # Returns (v,u) if self == (u,v).
    def reverse
      self.class.new(target, source, number, label)
    end

    # Allow for hashing of self loops.
    def hash
      super ^ number.hash
    end

    def to_s
      super + "[#{number}]"
    end

    def <=>(rhs)
      (result = super(rhs)) == 0 ? number <=> rhs.number : result
    end

    def inspect
      "#{self.class.to_s}[#{source.inspect},#{target.inspect},#{number.inspect},#{label.inspect}]"
    end

    def eql?(rhs)
      super(rhs) and (rhs.number.nil? or number.nil? or number == rhs.number)
    end

    def ==(rhs)
      eql?(rhs)
    end

    # Shortcut constructor. Instead of Arc.new(1,2) one can use Arc[1,2]
    def self.included(cl)
      # FIXME: lacks a cl.class_eval, no?
      def cl.[](p_source, p_target, p_number = nil, p_label = nil)
        new(p_source, p_target, p_number, p_label)
      end
    end
  end
end
