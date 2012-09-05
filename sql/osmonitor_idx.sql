DROP INDEX IF EXISTS idx_relation_members_member_id;
CREATE INDEX idx_relation_members_member_id
  ON relation_members
  USING btree
  (member_id );

DROP INDEX IF EXISTS idx_relation_members_relation_id;
CREATE INDEX idx_relation_members_relation_id
  ON relation_members
  USING btree
  (relation_id );

--DROP INDEX IF EXISTS idx_way_nodes_node_id;
--CREATE INDEX idx_way_nodes_node_id
--  ON way_nodes
--  USING btree
--  (node_id );

DROP INDEX IF EXISTS idx_way_nodes_way_id;
CREATE INDEX idx_way_nodes_way_id
  ON way_nodes
  USING btree
  (way_id );

DROP INDEX IF EXISTS idx_ways_refs;
CREATE INDEX idx_ways_refs
  ON ways
  USING gin
  (refs);

DROP INDEX IF EXISTS idx_ways_timestamp;
CREATE INDEX idx_ways_timestamp
  ON ways
  USING btree
  (tstamp );
