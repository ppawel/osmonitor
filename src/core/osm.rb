
# Determines if given tags and/or relation member role way defines a highway link.
def is_link?(member_role, tags)
  member_role == 'link' or (tags['highway'] and tags['highway'].include?('link'))
end

# Represents a node in OSM sense.
class Node
  attr_accessor :id
  attr_accessor :tags
  attr_accessor :x
  attr_accessor :y

  def initialize(id, tags)
    self.id = id
    self.tags = tags
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

# Represents a way in OSM sense.
class Way
  attr_accessor :id
  attr_accessor :member_role
  attr_accessor :tags
  attr_accessor :geom
  attr_accessor :relation
  attr_accessor :length
  attr_accessor :lengths
  attr_accessor :in_relation

  def initialize(id, member_role, tags)
    self.id = id
    self.member_role = member_role
    self.tags = tags
  end

  def oneway?
    tags['oneway'] and ['yes', 'true', '1'].include?(tags['oneway'].downcase)
  end

  def length
    return @length if @length
    lengths.reduce(0) {|total, l| total + l}
  end

  def to_s
    "Way(#{id}, length = #{length})"
  end

  def hash
    return id
  end

  def ==(o)
    o.class == self.class and o.id == id
  end
  alias_method :eql?, :==
end
