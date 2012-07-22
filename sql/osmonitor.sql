DROP FUNCTION OSM_GetDataTimestamp;

CREATE FUNCTION OSM_GetDataTimestamp() RETURNS TIMESTAMP AS $$
	SELECT MAX(tstamp) FROM relations
$$ LANGUAGE SQL;

DROP FUNCTION OSM_GetRelationBBox(bigint);

CREATE FUNCTION OSM_GetRelationBBox(bigint) RETURNS geometry AS $$
	SELECT Box2D(ST_Union(w.linestring))::geometry
	FROM relation_members rm
	INNER JOIN ways w ON (w.id = rm.member_id)
	WHERE rm.relation_id = $1 AND member_type = 'W'
$$ LANGUAGE SQL;

DROP TABLE relation_boundaries;

CREATE TABLE relation_boundaries (
  relation_id bigint NOT NULL,
  bbox geometry NOT NULL
);

INSERT INTO relation_boundaries SELECT 49715, OSM_GetRelationBBox(49715);
