-- Way "ref" tag values are put in this column because matching ref against hstore string values like "A1; S3" is slow.
ALTER TABLE ways ADD COLUMN refs text[];

DROP FUNCTION IF EXISTS OSM_Preprocess();

-- Preprocesses some stuff so Ruby does not have to work so hard on reports.
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

DROP FUNCTION IF EXISTS OSM_RefreshChangedRoads();
CREATE FUNCTION OSM_RefreshChangedRoads() RETURNS void AS $$
DECLARE
	ref CURSOR FOR SELECT * FROM osmonitor_roads ORDER BY id;
	all_rows float;
	i int;
	changed int;
BEGIN
SET enable_seqscan = off;
i := 0;
all_rows := (SELECT COUNT(*) FROM osmonitor_roads);

FOR road IN ref LOOP
	i := i + 1;
	raise notice '% Processing road % (% of % - %%%)', clock_timestamp(), road.id, i, all_rows, ((i / all_rows) * 100)::integer;

	changed := (SELECT COUNT(*)
		FROM osmonitor_road_data orr
		INNER JOIN osmonitor_roads r ON (r.id = orr.road_id)
		INNER JOIN ways w ON (w.id = orr.way_id)
		WHERE r.id = road.id AND w.tstamp > orr.way_last_update_timestamp);

	raise notice ' changed = %', changed;

	IF changed > 0 THEN
		PERFORM OSM_RefreshRoadData(road.id);
		raise notice ' refreshed';
	END IF;
END LOOP;
END;
$$ LANGUAGE plpgsql;
