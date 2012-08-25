-- Import the table data from the data files using the fast COPY method.
\copy users FROM 'users.txt'
\copy nodes FROM 'nodes.txt'
\copy ways FROM (id, version, user_id, tstamp, changeset_id, tags, nodes) 'ways.txt'
\copy way_nodes (way_id, node_id, sequence_id) FROM 'way_nodes.txt'
\copy relations FROM 'relations.txt'
\copy relation_members FROM 'relation_members.txt'

-- Comment these out if the COPY files include bbox or linestring column values.
-- Update the bbox column of the way table.
UPDATE ways SET bbox = (
	SELECT Envelope(Collect(geom))
	FROM nodes JOIN way_nodes ON way_nodes.node_id = nodes.id
	WHERE way_nodes.way_id = ways.id
);
-- Update the linestring column of the way table.
UPDATE ways w SET linestring = (
	SELECT ST_MakeLine(c.geom) AS way_line FROM (
		SELECT n.geom AS geom
		FROM nodes n INNER JOIN way_nodes wn ON n.id = wn.node_id
		WHERE (wn.way_id = w.id) ORDER BY wn.sequence_id
	) c
);

-- Update all clustered tables because it doesn't happen implicitly.
CLUSTER nodes USING idx_nodes_geom;
CLUSTER ways USING idx_ways_linestring;
