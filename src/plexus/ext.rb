class Object
  # Get the singleton class of the object.
  # Depending on the object which requested its singleton class,
  # a `module_eval` or a `class_eval` will be performed.
  # Object of special constant type (`Fixnum`, `NilClass`, `TrueClass`,
  # `FalseClass` and `Symbol`) return `nil` as they do not have a
  # singleton class.
  #
  # @return the singleton class
  def singleton_class
    if self.respond_to? :module_eval
      self.module_eval("class << self; self; end")
    elsif self.respond_to? :instance_eval
      begin
        self.instance_eval("class << self; self; end")
      rescue TypeError
        nil
      end
    end
  end

  # Check wether the object is of the specified kind.
  # If the receiver has a singleton class, will also perform
  # the check on its singleton class' ancestors, so as to catch
  # any included modules for object instances.
  #
  # Example:
  #
  #     class A; include Digraph; end
  #     a.singleton_class.ancestors
  #     # => [Plexus::DirectedGraph::Algorithms, ...
  #           Plexus::Labels, Enumerable, Object, Plexus, Kernel, BasicObject]
  #     a.is_a? Plexus::Graph
  #     # => true
  #
  # @param [Class] klass
  # @return [Boolean]
  def is_a? klass
    sc = self.singleton_class
    if not sc.nil?
      self.singleton_class.ancestors.include?(klass) || super
    else
      super
    end
  end
end

class Module
  # Helper which purpose is, given a class including a module,
  # to make each methods defined within a module's submodule `ClassMethods`
  # available as class methods to the receiving class.
  #
  # Example:
  #
  #     module A
  #       extends_host
  #       module ClassMethods
  #         def selfy; puts "class method for #{self}"; end
  #       end
  #     end
  #
  #     class B; include A; end
  #
  #     B.selfy
  #     # => class method for B
  #
  # @option *params [Symbol] :with (:ClassMethods) the name of the
  #   module to extend the receiver with
  def extends_host(*params)
    args = (params.pop if params.last.is_a? Hash) || {}
    @_extension_module = args[:with] || :ClassMethods

    def included(base)
      unless @_extension_module.nil?
        base.extend(self.const_get(@_extension_module))
      end
    end
  end
end
