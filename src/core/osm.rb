# Represents an OSM relation.
class Relation
  attr_accessor :id
  attr_accessor :tags

  def initialize(id, tags)
    self.id = id
    self.tags = tags
  end

  def distance
    @tags['distance'].gsub(/,/, '.').to_f if @tags['distance']
  end
end

# Represents a node in OSM sense.
class Node
  attr_accessor :id
  attr_accessor :tags
  attr_accessor :point_wkt

  def initialize(id, tags, wkt)
    self.id = id
    self.tags = tags
    self.point_wkt = wkt
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
  attr_accessor :segments
  attr_accessor :in_relation

  def initialize(id, member_role, tags)
    self.id = id
    self.member_role = member_role
    self.tags = tags
    self.segments = []
  end

  def add_segment(node1, node2, dist)
    segment = WaySegment.new(self, node1, node2, dist)
    @segments << segment
    segment
  end

  def oneway?
    return true if tags['oneway'] and ['yes', 'true', '1'].include?(tags['oneway'].downcase)
    return true if tags['junction'] == 'roundabout'
    return false
  end

  def length
    @segments.reduce(0) {|total, segment| total + segment.length}
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

# Represents a segment of an OSM way - part between two nodes belonging to the same way. A way can have multiple segments.
class WaySegment
  attr_accessor :from_node
  attr_accessor :to_node
  attr_accessor :way
  attr_accessor :length

  def initialize(way, from_node, to_node, dist)
    self.way = way
    self.from_node = from_node
    self.to_node = to_node
    self.length = dist
  end

  def to_s
    "WaySegment(#{from_node}->#{to_node})"
  end
end
