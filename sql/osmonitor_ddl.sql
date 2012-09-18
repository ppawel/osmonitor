-- Way "ref" tag values are put in this column because matching ref against hstore string values like "A1; S3" is slow.
ALTER TABLE ways ADD COLUMN refs text[];

DROP TABLE IF EXISTS osmonitor_config_options;
CREATE TABLE osmonitor_config_options (
  option_key text NOT NULL PRIMARY KEY,
  text_value text,
  geom_value geometry,
  date_value timestamp without time zone
);

DROP TABLE IF EXISTS osmonitor_road_relations;
CREATE TABLE osmonitor_road_relations (
  road_id text,
  relation_id integer,
  UNIQUE (road_id, relation_id)
);

DROP TABLE IF EXISTS osmonitor_road_data;
CREATE TABLE osmonitor_road_data (
  road_id text,
  way_last_update_user_id INTEGER,
  way_last_update_user_name TEXT,
  way_last_update_timestamp timestamp without time zone,
  way_last_update_changeset_id INTEGER,
  relation_id INTEGER,
  member_role text,
  relation_sequence_id INTEGER,
  node_sequence_id INTEGER,
  way_id BIGINT,
  way_tags hstore,
  way_geom text,
  node_geom text,
  node_id BIGINT,
  node_dist_to_next double precision
);

DROP TABLE IF EXISTS osmonitor_roads;
CREATE TABLE osmonitor_roads (
  id text PRIMARY KEY,
  data_timestamp timestamp without time zone,
  report_timestamp timestamp without time zone,
  country character varying(5),
  ref character varying(20),
  status bytea,
  UNIQUE (country, ref)
);

ALTER TABLE osmonitor_road_data ADD CONSTRAINT fk_osmonitor_road_data_road_id FOREIGN KEY (road_id) REFERENCES osmonitor_roads (id)
   ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE osmonitor_road_relations ADD CONSTRAINT fk_osmonitor_road_relations_road_id FOREIGN KEY (road_id) REFERENCES osmonitor_roads (id)
   ON UPDATE CASCADE ON DELETE CASCADE;
