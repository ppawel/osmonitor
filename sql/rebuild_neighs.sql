TRUNCATE node_neighs;

INSERT INTO node_neighs (
	-- node_id, neigh_id, way_id
	SELECT DISTINCT
		wn.node_id,
		wn_neigh.node_id,
		wn.way_id
	FROM way_nodes wn
	INNER JOIN way_nodes wn_neigh ON (wn_neigh.way_id = wn.way_id AND (wn_neigh.sequence_id = wn.sequence_id - 1 OR wn_neigh.sequence_id = wn.sequence_id + 1))
--	INNER JOIN relation_members rm ON (rm.member_id = wn.way_id)
);
		