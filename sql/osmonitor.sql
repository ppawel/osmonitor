﻿DROP FUNCTION OSM_GetDataTimestamp();

CREATE FUNCTION OSM_GetDataTimestamp() RETURNS TIMESTAMP AS $$
	SELECT MAX(tstamp) FROM relations
$$ LANGUAGE SQL;

DROP FUNCTION OSM_GetRelationGeometry(bigint);

CREATE FUNCTION OSM_GetRelationGeometry(bigint) RETURNS geometry AS $$
	SELECT ST_Union(w.linestring)::geometry
	FROM relation_members rm
	INNER JOIN ways w ON (w.id = rm.member_id)
	WHERE rm.relation_id = $1 AND member_type = 'W'
$$ LANGUAGE SQL;

DROP FUNCTION OSM_IsMostlyCoveredBy(bigint, bigint);

CREATE FUNCTION OSM_IsMostlyCoveredBy(bigint, bigint) RETURNS boolean AS $$
	SELECT (SELECT COUNT(*)
		FROM (SELECT ST_Contains((SELECT hull FROM relation_boundaries WHERE relation_id = $1), linestring) AS is
			FROM relation_members rm
			INNER JOIN ways w ON (w.id = rm.member_id)
			WHERE rm.relation_id = $2 AND member_type = 'W') AS covered WHERE covered.is)::float * 100
		  > ((SELECT COUNT(*)
		FROM relation_members rm
		INNER JOIN ways w ON (w.id = rm.member_id)
		WHERE rm.relation_id = $2 AND member_type = 'W') + 1)::float * 50
$$ LANGUAGE SQL;

DROP FUNCTION OSM_GetRelationLength(bigint);

CREATE FUNCTION OSM_GetRelationLength(bigint) RETURNS integer AS $$
	SELECT SUM(ST_Length(linestring::geography))::integer
	FROM relation_members rm
	INNER JOIN ways w ON (w.id = rm.member_id)
	WHERE rm.relation_id = $1 AND member_type = 'W' AND (member_role IN ('forward', 'member', '') OR member_role IS NULL)
$$ LANGUAGE SQL;

DROP TABLE relation_boundaries;

CREATE TABLE relation_boundaries (
  relation_id bigint NOT NULL,
  hull geometry NOT NULL
);

--INSERT INTO relation_boundaries SELECT 49715, ST_ConcaveHull(OSM_GetRelationGeometry(49715), 0.99);
INSERT INTO relation_boundaries VALUES (936128, ST_PolygonFromText('POLYGON((16.118053 50.657799,16.071388 50.635551,16.024441 50.629997,15.946943 50.689438,15.787498 50.744164,15.606667 50.772774,15.488333 50.786659,15.379720 50.779442,15.362846 50.840622,15.311666 50.860344,15.282777 50.892078,15.272499 50.924511,15.290416 50.948956,15.275276 50.974998,15.239443 50.991943,15.176943 51.014717,15.016388 50.974094,15.019165 50.950554,15.003887 50.867496,14.966665 50.859161,14.828333 50.865829,14.826179 50.883053,14.896944 50.959442,14.931110 51.002495,14.965555 51.052216,14.978888 51.078331,14.994444 51.118607,15.032221 51.239166,15.033818 51.286659,15.002638 51.316799,14.983333 51.333611,14.971666 51.357220,14.981833 51.368050,14.975555 51.440826,14.953054 51.469994,14.921110 51.481941,14.837500 51.498604,14.739444 51.526524,14.714998 51.554722,14.759235 51.607494,14.756110 51.666733,14.722082 51.690968,14.698055 51.702217,14.667985 51.723885,14.600971 51.820065,14.610138 51.848190,14.645415 51.865276,14.689860 51.896942,14.717551 51.943111,14.760765 52.069862,14.707915 52.245621,14.692497 52.254440,14.655832 52.260277,14.598886 52.272774,14.579860 52.288330,14.534443 52.396248,14.543958 52.421871,14.563193 52.433189,14.585137 52.439857,14.633540 52.490551,14.639582 52.572979,14.595778 52.606831,14.554582 52.627220,14.514443 52.639164,14.478749 52.652496,14.448332 52.675278,14.383333 52.730827,14.355000 52.748329,14.205416 52.818607,14.149166 52.862778,14.147637 52.959232,14.168888 52.973328,14.200277 52.984718,14.225415 52.988884,14.293739 53.018768,14.347361 53.048885,14.380277 53.110134,14.391689 53.144165,14.412777 53.304443,14.413261 53.338959,14.309721 53.555550,14.275627 53.699066,14.366110 53.699440,14.410693 53.680550,14.525000 53.660553,14.554722 53.678604,14.620277 53.767914,14.614166 53.816383,14.580832 53.847496,14.553472 53.857773,14.476665 53.864578,14.412568 53.859924,14.339443 53.804855,14.289999 53.822777,14.266109 53.836662,14.218887 53.869019,14.215832 53.899994,14.225555 53.928604,14.249861 53.922356,14.327776 53.912498,14.350277 53.910553,14.376388 53.912220,14.425416 53.922497,14.483332 53.947220,14.504304 53.959164,14.559444 53.976662,14.745277 54.028610,14.814444 54.039162,14.979721 54.071388,15.228054 54.129440,15.302777 54.147774,15.353888 54.156387,15.395859 54.160629,15.429443 54.162216,15.493472 54.166523,15.654166 54.193886,15.752360 54.214165,15.794167 54.226105,15.839304 54.241386,15.876389 54.246384,16.047775 54.261665,16.081387 54.254303,16.144026 54.252914,16.174721 54.259163,16.217777 54.273605,16.329441 54.356800,16.304928 54.372288,16.318333 54.391106,16.408222 54.461525,16.460552 54.499718,16.489529 54.518669,16.515553 54.534164,16.543610 54.544716,16.571663 54.551109,16.638611 54.563606,16.665276 54.566940,16.701942 54.568745,16.793331 54.575829,16.884163 54.589722,16.915276 54.597771,16.939442 54.605412,17.019165 54.647495,17.036526 54.660553,17.065832 54.673470,17.251108 54.730274,17.362221 54.747772,17.434166 54.752777,17.530552 54.762215,17.592915 54.769997,17.686607 54.789093,17.774441 54.806389,17.896942 54.823883,17.918888 54.826660,18.043331 54.834026,18.336109 54.836037,18.372776 54.816109,18.449333 54.788273,18.526833 54.760773,18.578165 54.744106,18.605833 54.735607,18.703888 54.700272,18.739998 54.685272,18.774719 54.666382,18.832672 54.621037,18.820969 54.593742,18.786110 54.618607,18.772081 54.633610,18.755554 54.656105,18.730831 54.678329,18.706247 54.693607,18.571943 54.729660,18.503942 54.753498,18.483400 54.759121,18.466944 54.736832,18.406109 54.738190,18.468330 54.665833,18.511387 54.631104,18.547775 54.587704,18.566664 54.550690,18.569790 54.476662,18.574303 54.446526,18.595205 54.427773,18.708332 54.382774,18.757774 54.370827,18.843748 54.351803,18.893192 54.345551,18.927359 54.346386,18.953888 54.351662,18.970552 54.345135,19.022778 54.342216,19.046387 54.342216,19.138885 54.346664,19.212498 54.353882,19.374443 54.373604,19.417500 54.380554,19.439720 54.385826,19.516804 54.407082,19.562775 54.428886,19.613331 54.454720,19.627258 54.463272,19.651108 54.455826,19.630344 54.443069,19.524441 54.396660,19.428333 54.365273,19.408051 54.358887,19.376108 54.352497,19.277636 54.346107,19.230761 54.333672,19.253330 54.278187,19.371109 54.268600,19.478746 54.314159,19.571039 54.346939,19.628746 54.350548,19.713608 54.383331,19.797007 54.437550,19.857704 54.429909,20.004166 54.419159,20.090553 54.418602,20.158607 54.411934,20.301388 54.397774,20.329082 54.393833,20.331182 54.393532,20.371662 54.387772,20.432774 54.381660,20.738884 54.358047,20.898052 54.356102,21.126385 54.341660,21.181938 54.336380,21.231937 54.332771,21.283607 54.329994,21.367218 54.327217,21.411942 54.325829,21.442493 54.325554,21.524166 54.326942,21.570435 54.328209,21.577515 54.328403,21.625553 54.329720,21.731380 54.330833,21.855553 54.331665,21.981937 54.332771,22.164997 54.334991,22.265553 54.338043,22.296150 54.339909,22.429731 54.345543,22.455551 54.345543,22.629997 54.348877,22.664162 54.351105,22.766665 54.359718,22.785885 54.363838,22.812220 54.395966,22.835136 54.405128,22.863190 54.408321,22.995066 54.385757,23.115829 54.304436,23.204441 54.287216,23.333054 54.247215,23.356108 54.235409,23.457771 54.174160,23.484440 54.138329,23.494160 54.117210,23.517498 54.038746,23.508053 53.960548,23.504040 53.947044,23.502777 53.942490,23.503887 53.921379,23.510012 53.899323,23.539719 53.840828,23.580551 53.731102,23.590443 53.694431,23.592775 53.685268,23.608608 53.637497,23.617218 53.614021,23.640274 53.559158,23.673536 53.493744,23.700550 53.453049,23.785917 53.314335,23.858608 53.195824,23.933191 53.012077,23.927492 52.948376,23.931385 52.858604,23.938660 52.774712,23.939716 52.770271,23.941105 52.749718,23.935274 52.717487,23.911800 52.693184,23.883884 52.678047,23.746801 52.614647,23.715824 52.615952,23.688328 52.617210,23.655273 52.610275,23.633606 52.605553,23.597218 52.596382,23.523052 52.573608,23.503609 52.567497,23.417217 52.525269,23.397217 52.514442,23.377495 52.498329,23.248383 52.374485,23.165400 52.282276,23.192772 52.233189,23.214716 52.223461,23.297775 52.211662,23.348330 52.206795,23.594997 52.111938,23.638607 52.079437,23.660828 52.006104,23.626801 51.952076,23.612482 51.915955,23.558052 51.752495,23.547775 51.686378,23.555483 51.665199,23.534992 51.653595,23.539165 51.592766,23.567175 51.539600,23.604633 51.527695,23.614086 51.498627,23.643635 51.485012,23.692772 51.402351,23.681246 51.369297,23.683884 51.288605,23.731937 51.214714,23.756664 51.199432,23.811108 51.168884,23.904997 51.068054,23.931665 50.994072,23.965134 50.950405,23.988327 50.931107,24.034302 50.898254,24.061497 50.887524,24.090275 50.881935,24.143469 50.859577,24.131037 50.838184,24.076942 50.829437,24.052498 50.831383,24.021894 50.831753,23.980967 50.829578,23.958397 50.815201,23.954386 50.791702,24.014721 50.739990,24.072220 50.695824,24.107220 50.633606,24.108414 50.625900,24.111385 50.566940,24.002218 50.414436,23.983189 50.405960,23.929440 50.403603,23.881496 50.405411,23.846943 50.406654,23.814442 50.405823,23.791943 50.402489,23.755833 50.394440,23.717590 50.383839,23.697111 50.370113,23.684175 50.333698,23.591106 50.269157,23.568886 50.255829,23.540276 50.242779,23.496105 50.220825,23.378330 50.149719,23.342823 50.127491,23.324440 50.115273,23.303608 50.100830,23.228189 50.046661,23.146107 49.983047,23.110828 49.954994,22.779999 49.674995,22.717216 49.604439,22.686068 49.577095,22.678467 49.569439,22.656870 49.529854,22.694439 49.450829,22.732788 49.397209,22.758818 49.285896,22.726662 49.217766,22.703814 49.169888,22.778053 49.150543,22.852776 49.105827,22.876522 49.087421,22.863504 49.049831,22.886074 49.002914,22.863050 49.003048,22.737774 49.047218,22.594147 49.091534,22.568470 49.087910,22.558052 49.079437,22.537777 49.087914,22.348886 49.138470,22.323887 49.138611,22.224998 49.154716,22.029894 49.220238,22.025276 49.247215,22.020136 49.273884,21.958611 49.340275,21.838055 49.384438,21.612638 49.436523,21.533607 49.429718,21.500832 49.422218,21.459303 49.411942,21.436386 49.413887,21.400845 49.429054,21.281944 49.456387,21.071527 49.422081,21.050554 49.410549,21.035553 49.359718,20.982359 49.309441,20.955830 49.301666,20.913609 49.296104,20.812496 49.330826,20.740833 49.388885,20.602776 49.395554,20.360554 49.393051,20.327774 49.383331,20.206665 49.340271,20.143608 49.314995,20.103333 49.248604,20.092636 49.204857,20.073364 49.177876,20.039165 49.188889,20.020554 49.199440,19.998896 49.217625,19.979582 49.226387,19.936386 49.231110,19.911247 49.226173,19.867910 49.197132,19.842915 49.191803,19.783470 49.200203,19.765970 49.214439,19.773609 49.233055,19.798054 49.252777,19.825657 49.277565,19.804996 49.364716,19.778017 49.407494,19.710552 49.397499,19.658607 49.406662,19.577082 49.459023,19.535275 49.535553,19.520981 49.574165,19.475555 49.599998,19.447777 49.600830,19.269026 49.526661,19.242359 49.506802,19.199303 49.437775,19.191666 49.414024,19.159580 49.400272,19.031666 49.391937,18.974928 49.401939,18.968330 49.456383,18.968609 49.481667,18.851246 49.517357,18.852219 49.527771,18.847775 49.554161,18.839443 49.594994,18.810831 49.673328,18.786942 49.681938,18.634163 49.737778,18.579350 49.814995,18.578747 49.912220,18.552706 49.922424,18.350277 49.938889,18.270275 49.957771,18.094166 50.038055,18.053162 50.055931,18.009441 50.011108,17.920691 49.977360,17.876247 49.978954,17.840137 49.989578,17.657776 50.108055,17.606318 50.162701,17.642776 50.171944,17.695276 50.179024,17.763678 50.209370,17.762915 50.233330,17.753052 50.297775,17.724442 50.319023,17.697012 50.320271,17.693470 50.299995,17.661110 50.272358,17.626804 50.265549,17.433052 50.270271,17.378330 50.279442,17.283607 50.320274,17.226944 50.345276,17.205276 50.360970,17.118053 50.396660,17.057777 50.410553,16.941387 50.434998,16.910831 50.440132,16.890968 50.438675,16.868748 50.411179,16.937496 50.340553,16.972775 50.309998,17.002220 50.216942,16.968609 50.222771,16.911386 50.222359,16.846943 50.201801,16.811247 50.179440,16.802935 50.169651,16.786663 50.140549,16.715345 50.098328,16.639997 50.108887,16.614441 50.119720,16.587776 50.139999,16.565969 50.170345,16.562222 50.208191,16.548054 50.227081,16.458611 50.303604,16.441387 50.316666,16.371944 50.361107,16.303055 50.378052,16.266109 50.389717,16.219027 50.410275,16.207739 50.439022,16.314999 50.504719,16.358923 50.497910,16.406666 50.523048,16.447359 50.578815,16.430277 50.601524,16.369999 50.644165,16.332012 50.664024,16.237499 50.670555,16.137497 50.656105,16.118053 50.657799))', 4326));

--INSERT INTO relation_boundaries SELECT 1372452, ST_ConcaveHull(OSM_GetRelationGeometry(1372452), 0.99);
