-- Need this to avoid joining with nodes table to get node geometry which is extremely painful.
ALTER TABLE way_nodes ADD COLUMN node_geom geometry;

-- Used to preprocess distance from one node to the next node.
ALTER TABLE way_nodes ADD COLUMN dist_to_next double precision;

-- Way "ref" tag values are put in this column because matching ref against hstore string values like "A1; S3" is slow.
ALTER TABLE ways ADD COLUMN refs text[];

DROP FUNCTION OSM_PreprocessUsingCursor();

-- Preprocesses some stuff so Ruby does not have to work so hard on reports.
CREATE FUNCTION OSM_PreprocessUsingCursor() RETURNS void AS $$
DECLARE
	ref CURSOR FOR SELECT * FROM ways WHERE OSM_GetConfigDateValue('last_preprocessing_data_timestamp') IS NULL OR tstamp > OSM_GetConfigDateValue('last_preprocessing_data_timestamp');
	all_rows float;
	i int;
  data_timestamp timestamp;
BEGIN
i := 0;
all_rows := (SELECT COUNT(*) FROM ways WHERE OSM_GetConfigDateValue('last_preprocessing_data_timestamp') IS NULL OR tstamp > OSM_GetConfigDateValue('last_preprocessing_data_timestamp'));

FOR way IN ref LOOP
	i := i + 1;
	raise notice '% Processing way % (% of % - %%%)', clock_timestamp(), way.id, i, all_rows, ((i / all_rows) * 100)::integer;

	UPDATE way_nodes wn
	SET node_geom = (SELECT n.geom FROM nodes n WHERE n.id = wn.node_id)
	WHERE wn.way_id = way.id;

	raise notice '   Done update 1';

	UPDATE way_nodes wn SET dist_to_next = ST_Distance_Sphere(wn.node_geom,
		(SELECT
			wn_next.node_geom
		FROM way_nodes wn_next
		WHERE wn_next.way_id = wn.way_id AND
			wn_next.sequence_id = wn.sequence_id + 1))
	WHERE wn.way_id = way.id;

	raise notice '   Done update 2';

	UPDATE
		ways w
	SET refs = 
		(CASE
			WHEN position(',' in tags -> 'ref') > 0 THEN string_to_array(REPLACE(tags -> 'ref', ' ', ''), ',')
			WHEN position(';' in tags -> 'ref') > 0 THEN string_to_array(REPLACE(tags -> 'ref', ' ', ''), ';')
			ELSE ARRAY[REPLACE(tags-> 'ref', ' ', '')]
		END)
	WHERE tags ? 'ref' AND w.id = way.id;

	raise notice '   Done update 3';
END LOOP;

data_timestamp := (SELECT OSM_GetDataTimestamp());
raise notice 'Finished, data timestamp is %', data_timestamp;
UPDATE config_options SET date_value = data_timestamp WHERE option_key = 'last_preprocessing_data_timestamp';

END;
$$ LANGUAGE plpgsql;
