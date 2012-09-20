# Holds data for an update (edit) operation on some OSM entity.
class Changeset
  attr_accessor :user_id
  attr_accessor :user_name
  attr_accessor :changeset_id
  attr_accessor :timestamp

  def initialize(user_id, user_name, timestamp, changeset_id)
    self.user_id = user_id
    self.user_name = user_name
    self.changeset_id = changeset_id
    self.timestamp = timestamp
  end
end

# Represents an OSM relation.
class Relation
  attr_accessor :id
  attr_accessor :tags
  attr_accessor :last_update

  def initialize(row)
    self.id = row['id'].to_i
    self.tags = row['tags']
    self.last_update = Changeset.new(row['last_update_user_id'].to_i, row['last_update_user_name'],
      row['last_update_timestamp'], row['last_update_changeset_id'])
  end

  def distance
    @tags['distance'].gsub(/,/, '.').to_f if @tags['distance']
  end

  def to_s
    "Relation(id = #{@id}, tags = #{@tags}"
  end
end

# Represents a node in OSM sense.
class Node
  attr_accessor :id
  attr_accessor :tags
  attr_accessor :point_wkb

  def initialize(id, tags, wkb)
    self.id = id
    self.tags = tags
    self.point_wkb = wkb
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
  attr_accessor :last_update

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

  def in_relation?
    !@relation.nil?
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
