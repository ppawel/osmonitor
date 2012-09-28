DROP INDEX IF EXISTS idx_relation_members_member_id;
CREATE INDEX idx_relation_members_member_id
  ON relation_members
  USING btree
  (member_id);

DROP INDEX IF EXISTS idx_relation_members_relation_id;
CREATE INDEX idx_relation_members_relation_id
  ON relation_members
  USING btree
  (relation_id);

--DROP INDEX IF EXISTS idx_way_nodes_node_id;
--CREATE INDEX idx_way_nodes_node_id
--  ON way_nodes
--  USING btree
--  (node_id );

DROP INDEX IF EXISTS idx_way_nodes_way_id;
CREATE INDEX idx_way_nodes_way_id
  ON way_nodes
  USING btree
  (way_id);

DROP INDEX IF EXISTS idx_ways_refs;
CREATE INDEX idx_ways_refs
  ON ways
  USING gin
  (refs);

DROP INDEX IF EXISTS idx_ways_refs_btree;
CREATE INDEX idx_ways_refs_btree
  ON ways
  USING btree
  (refs);

DROP INDEX IF EXISTS idx_ways_timestamp;
CREATE INDEX idx_ways_timestamp
  ON ways
  USING btree
  (tstamp);

DROP INDEX IF EXISTS idx_osmonitor_roads_ref;
CREATE INDEX idx_osmonitor_roads_ref
   ON osmonitor_roads
   USING btree
   (ref ASC NULLS LAST, country ASC NULLS LAST);

DROP INDEX IF EXISTS idx_osmonitor_road_data_road_id;
CREATE INDEX idx_osmonitor_road_data_road_id
  ON osmonitor_road_data
  USING btree
  (road_id);

DROP INDEX IF EXISTS idx_osmonitor_road_relations_road_id;
CREATE INDEX idx_osmonitor_road_relations_road_id
  ON osmonitor_road_relations
  USING btree
  (road_id);

DROP INDEX IF EXISTS idx_osmonitor_road_data_distance_calc_index;
CREATE INDEX idx_osmonitor_road_data_distance_calc_index
  ON osmonitor_road_data
  USING btree
  (road_id, way_id, node_sequence_id);

DROP INDEX IF EXISTS idx_relations_tags;
CREATE INDEX idx_relations_tags
  ON relations
  USING gist
  (tags);

DROP INDEX IF EXISTS idx_osmonitor_actions_id_data_type;
CREATE INDEX idx_osmonitor_actions_id_data_type
  ON osmonitor_actions
  USING btree
  (id, data_type;
