
# Determines if given tags and/or relation member role way defines a highway link.
def is_link?(member_role, tags)
  member_role == 'link' or (tagstags['highway'] and tags['highway'].include?('link'))
end

# Represents a node in OSM sense.
class Node
  attr_accessor :id
  attr_accessor :tags
  attr_accessor :ways
  attr_accessor :x
  attr_accessor :y

  def initialize(id, tags)
    self.id = id
    self.tags = tags
    self.ways = {}
  end

  def add_way(way)
    @ways[way.id] = way
  end

  def get_mutual_way(node)
    common_way_ids = node.ways.keys & @ways.keys
    return @ways[common_way_ids[0]] if !common_way_ids.empty?
  end

  def hash
    return id
  end

  def ==(o)
    o.class == self.class and o.id == id
  end
  alias_method :eql?, :==

  def to_s
    return "Node(#{id})"
  end
end

def member_role_all?(role)
  ['', 'member', 'route'].include?(role)
end

def member_role_backward?(role)
  member_role_all?(role) or ['backward'].include?(role)
end

def member_role_forward?(role)
  member_role_all?(role) or ['forward'].include?(role)
end

# Represents a way in OSM sense.
class Way
  attr_accessor :id
  attr_accessor :member_role
  attr_accessor :tags
  attr_accessor :geom
  attr_accessor :relation
  attr_accessor :length
  attr_accessor :in_relation

  def initialize(id, member_role, tags)
    self.id = id
    self.member_role = member_role
    self.tags = tags
  end

  def hash
    return id
  end

  def ==(o)
    o.class == self.class and o.id == id
  end
  alias_method :eql?, :==
end
