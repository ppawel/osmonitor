------
------ OSM_GetDataTimestamp
------
------ Preprocesses some stuff so Ruby does not have to work so hard on reports.
------
DROP FUNCTION IF EXISTS OSM_GetDataTimestamp();
CREATE FUNCTION OSM_GetDataTimestamp() RETURNS TIMESTAMP AS $$
  SELECT MAX(tstamp) FROM ways
$$ LANGUAGE SQL;

------
------ OSM_GetRelationGeometry(bigint)
------
------
------
DROP FUNCTION IF EXISTS OSM_GetRelationGeometry(bigint);
CREATE FUNCTION OSM_GetRelationGeometry(bigint) RETURNS geometry AS $$
  SELECT ST_Union(w.linestring)::geometry
  FROM relation_members rm
  INNER JOIN ways w ON (w.id = rm.member_id)
  WHERE rm.relation_id = $1 AND member_type = 'W'
$$ LANGUAGE SQL;

------
------ OSM_IsMostlyCoveredBy(text, bigint)
------
------ Checks if ways of a relation are "mostly covered" by given boundary geometry.
------ param 1 - option_key from table osmonitor_config_options
------ param 2 - relation id
------
DROP FUNCTION IF EXISTS OSM_IsMostlyCoveredBy(text, bigint);
CREATE FUNCTION OSM_IsMostlyCoveredBy(text, bigint) RETURNS boolean AS $$
  SELECT (SELECT COUNT(*)
    FROM (SELECT ST_Contains((SELECT geom_value FROM osmonitor_config_options WHERE option_key = $1), linestring) AS is
      FROM relation_members rm
      INNER JOIN ways w ON (w.id = rm.member_id)
      WHERE rm.relation_id = $2 AND member_type = 'W') AS covered WHERE covered.is)::float * 100
      > (SELECT COUNT(*)
    FROM relation_members rm
    INNER JOIN ways w ON (w.id = rm.member_id)
    WHERE rm.relation_id = $2 AND member_type = 'W')::float * 33
$$ LANGUAGE SQL;

------
------ OSM_RefreshRoadData(text)
------
------
------
DROP FUNCTION IF EXISTS OSM_RefreshRoadData(text);
CREATE FUNCTION OSM_RefreshRoadData(text) RETURNS void AS $$
DECLARE
  road RECORD;
  road_relation_id integer;
BEGIN
  SELECT * FROM osmonitor_roads WHERE id = $1 INTO road;
  road_relation_id := (SELECT relation_id FROM osmonitor_road_relations WHERE road_id = $1 ORDER BY relation_id LIMIT 1);

  RAISE NOTICE ' Road % (%): remove then insert road data again', road.ref, road.id;

  -- Remove then insert road data again.
  DELETE FROM osmonitor_road_data WHERE road_id = $1;
  RAISE NOTICE ' Removed';

  INSERT INTO osmonitor_road_data
	SELECT DISTINCT ON (way_id, node_sequence_id)
	*
	FROM
    ((SELECT
	road.id AS road_id,
      way_user.id AS way_last_update_user_id,
      way_user.name AS way_last_update_user_name,
      w.tstamp AS way_last_update_timestamp,
      w.changeset_id AS way_last_update_changeset_id,
      rm.relation_id AS relation_id,
      rm.member_role AS member_role,
      rm.sequence_id AS relation_sequence_id,
      wn.sequence_id AS node_sequence_id,
      wn.way_id AS way_id,
      w.tags AS way_tags,
      w.linestring AS way_geom,
      n.geom AS node_geom,
      wn.node_id AS node_id
    FROM way_nodes wn
    INNER JOIN relation_members rm ON (rm.member_id = way_id AND rm.member_type = 'W')
    INNER JOIN nodes n ON (n.id = wn.node_id)
    INNER JOIN ways w ON (w.id = wn.way_id)
    LEFT JOIN users way_user ON (way_user.id = w.user_id)
    WHERE road_relation_id IS NOT NULL AND rm.relation_id = road_relation_id) UNION
    (SELECT
    road.id AS road_id,
    way_user.id AS way_last_update_user_id,
    way_user.name AS way_last_update_user_name,
    w.tstamp AS way_last_update_timestamp,
    w.changeset_id AS way_last_update_changeset_id,
    NULL::bigint AS relation_id,
    NULL::text AS member_role,
    NULL::bigint AS relation_sequence_id,
    wn.sequence_id AS node_sequence_id,
    wn.way_id AS way_id,
    w.tags AS way_tags,
    w.linestring AS way_geom,
    n.geom AS node_geom,
    wn.node_id AS node_id
  FROM way_nodes wn
  INNER JOIN nodes n ON (n.id = wn.node_id)
  INNER JOIN ways w ON (w.id = wn.way_id)
  LEFT JOIN users way_user ON (way_user.id = w.user_id)
  WHERE
  w.refs @> ARRAY[road.ref]::text[] AND
  (NOT w.tags ?| ARRAY['aerialway', 'aeroway', 'building', 'waterway']) AND
    ((w.tags -> 'railway') IS NULL OR (w.tags -> 'highway') IS NOT NULL) AND
    ((w.tags -> 'highway') IS NULL OR w.tags -> 'highway' != 'cycleway') AND
  ST_NumPoints(w.linestring) > 1 AND
  (SELECT ST_Contains(OSM_GetConfigGeomValue('boundary_' || road.country), w.linestring)) = True)) query
  ORDER BY way_id, node_sequence_id, relation_sequence_id NULLS LAST, relation_id NULLS LAST;

  RAISE NOTICE ' Road % (%): recalculate', road.ref, road.id;

  -- Recalculate distances between nodes for this road.
  UPDATE osmonitor_road_data orr
  SET node_dist_to_next = ST_Distance_Sphere(orr.node_geom,
    (SELECT
      orr_next.node_geom
    FROM osmonitor_road_data orr_next
    WHERE orr_next.way_id = orr.way_id AND
      orr_next.road_id = orr.road_id AND
      orr_next.node_sequence_id = orr.node_sequence_id + 1))
  WHERE orr.road_id = $1;
END;
$$ LANGUAGE plpgsql;

------
------ OSM_UpdateRoadDataTimestamps
------
------
------
DROP FUNCTION IF EXISTS OSM_UpdateRoadDataTimestamps();
CREATE FUNCTION OSM_UpdateRoadDataTimestamps() RETURNS void AS $$
BEGIN
  UPDATE osmonitor_roads rds SET data_timestamp =
    (SELECT MAX(q.tstamp)
    FROM (SELECT MAX(way_last_update_timestamp) AS tstamp
  FROM osmonitor_road_data
  WHERE road_id = rds.id
  UNION
  SELECT MAX(tstamp) AS tstamp
  FROM osmonitor_road_relations orr
  INNER JOIN relations r ON (r.id = orr.relation_id)
  WHERE orr.road_id = rds.id) q);
END;
$$ LANGUAGE plpgsql;

------
------ OSM_RefreshRoadRelations(text)
------
------
------
DROP FUNCTION IF EXISTS OSM_RefreshRoadRelations(text);
CREATE FUNCTION OSM_RefreshRoadRelations(text) RETURNS void AS $$
DECLARE
  road RECORD;
BEGIN
  SELECT * FROM osmonitor_roads WHERE id = $1 INTO road;

  RAISE NOTICE 'Deleting existing relations...';

  DELETE FROM osmonitor_road_relations WHERE road_id = $1;

  RAISE NOTICE 'Inserting new relations...';
  
  INSERT INTO osmonitor_road_relations (road_id, relation_id)
    SELECT $1 AS road_id, r.id
    FROM relations r
    WHERE r.tags @> hstore(ARRAY[['type', 'route'], ['route', 'road'], ['ref', road.ref]]) AND
	OSM_IsMostlyCoveredBy('boundary_' || road.country, r.id) = true;
END;
$$ LANGUAGE plpgsql;

------
------ OSM_Preprocess
------
------ Preprocesses some stuff so Ruby does not have to work so hard on reports.
------
DROP FUNCTION IF EXISTS OSM_Preprocess();
CREATE FUNCTION OSM_Preprocess() RETURNS void AS $$
DECLARE
  ref CURSOR FOR SELECT * FROM ways WHERE OSM_GetConfigDateValue('last_preprocessing_data_timestamp') IS NULL OR tstamp > OSM_GetConfigDateValue('last_preprocessing_data_timestamp');
  all_rows float;
  i int;
  data_timestamp timestamp;
BEGIN
SET enable_seqscan = off;
i := 0;
all_rows := (SELECT COUNT(*) FROM ways WHERE OSM_GetConfigDateValue('last_preprocessing_data_timestamp') IS NULL OR tstamp > OSM_GetConfigDateValue('last_preprocessing_data_timestamp'));

FOR way IN ref LOOP
  i := i + 1;
  raise notice '% Processing way % (% of % - %%%)', clock_timestamp(), way.id, i, all_rows, ((i / all_rows) * 100)::integer;

  UPDATE
    ways w
  SET refs = 
    (CASE
      WHEN NOT tags ?| ARRAY['ref'] THEN ARRAY[]::text[]
      WHEN position(',' in tags -> 'ref') > 0 THEN string_to_array(REPLACE(tags -> 'ref', ' ', ''), ',')
      WHEN position(';' in tags -> 'ref') > 0 THEN string_to_array(REPLACE(tags -> 'ref', ' ', ''), ';')
      ELSE ARRAY[REPLACE(tags-> 'ref', ' ', '')]
    END)
  WHERE w.id = way.id;
END LOOP;

data_timestamp := (SELECT OSM_GetDataTimestamp());
raise notice 'Finished, data timestamp is %', data_timestamp;
UPDATE osmonitor_config_options SET date_value = data_timestamp WHERE option_key = 'last_preprocessing_data_timestamp';

END;
$$ LANGUAGE plpgsql;

--
-- OSM_RefreshChangedRoads
--
-- Preprocesses some stuff so Ruby does not have to work so hard on reports.
--
DROP FUNCTION IF EXISTS OSM_RefreshChangedRoads();
CREATE FUNCTION OSM_RefreshChangedRoads() RETURNS void AS $$
DECLARE
  ref CURSOR FOR SELECT * FROM osmonitor_roads ORDER BY id;
  all_rows float;
  i int;
  current_ways int;
  changed int;
BEGIN
i := 0;
all_rows := (SELECT COUNT(*) FROM osmonitor_roads);

FOR road IN ref LOOP
  i := i + 1;
  raise notice '% Processing road % (%) (% of % - %%%)', clock_timestamp(), road.ref, road.id, i, all_rows, ((i / all_rows) * 100)::integer;

  -- Check if relations have changed.
  changed := (SELECT COUNT(*)
    FROM osmonitor_road_relations orr
    INNER JOIN osmonitor_roads rds ON (rds.id = orr.road_id)
    INNER JOIN relations r ON (r.id = orr.relation_id)
    WHERE rds.id = road.id AND r.tstamp > rds.data_timestamp);

  IF changed = 0 THEN
    -- Check if existing road ways have changed.
    changed := (SELECT COUNT(*)
      FROM osmonitor_road_data orr
      INNER JOIN osmonitor_roads r ON (r.id = orr.road_id)
      INNER JOIN ways w ON (w.id = orr.way_id)
      WHERE r.id = road.id AND w.tstamp > orr.way_last_update_timestamp);
  END IF;

  raise notice '% changed = %', clock_timestamp(), changed;

  IF changed > 0 OR road.data_timestamp IS NULL THEN
    PERFORM OSM_RefreshRoadRelations(road.id);
    PERFORM OSM_RefreshRoadData(road.id);
    raise notice '% refreshed', clock_timestamp();
  END IF;
END LOOP;

PERFORM OSM_UpdateRoadDataTimestamps();
END;
$$ LANGUAGE plpgsql;

------------------------------
------------------------------ some helpers
------------------------------

DROP FUNCTION IF EXISTS OSM_GetConfigGeomValue(text);
CREATE FUNCTION OSM_GetConfigGeomValue(text) RETURNS geometry IMMUTABLE AS $$
  SELECT geom_value
  FROM osmonitor_config_options
  WHERE option_key = $1
$$ LANGUAGE SQL;

DROP FUNCTION IF EXISTS OSM_GetConfigDateValue(text);
CREATE FUNCTION OSM_GetConfigDateValue(text) RETURNS timestamp IMMUTABLE AS $$
  SELECT date_value
  FROM osmonitor_config_options
  WHERE option_key = $1
$$ LANGUAGE SQL;

DROP FUNCTION IF EXISTS OSM_GetConfigTextValue(text);
CREATE FUNCTION OSM_GetConfigTextValue(text) RETURNS text IMMUTABLE AS $$
  SELECT text_value
  FROM osmonitor_config_options
  WHERE option_key = $1
$$ LANGUAGE SQL;

DROP FUNCTION IF EXISTS exec(text);
CREATE FUNCTION exec(text) RETURNS text AS $$ BEGIN EXECUTE $1; RETURN $1; END $$ LANGUAGE plpgsql;
