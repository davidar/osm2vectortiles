CREATE OR REPLACE VIEW aeroway_z12toz14 AS
    SELECT *
    FROM osm_aero_linestring
    UNION ALL
    SELECT *
    FROM osm_aero_polygon;

CREATE OR REPLACE VIEW layer_aeroway AS (
    SELECT osm_id, timestamp, geometry FROM aeroway_z12toz14
);

CREATE OR REPLACE FUNCTION changed_tiles_aeroway(ts timestamp)
RETURNS TABLE (x INTEGER, y INTEGER, z INTEGER) AS $$
BEGIN
	RETURN QUERY (
		WITH created_or_updated_osm_ids AS (
	    	SELECT osm_id FROM osm_create 
	    	WHERE (table_name = 'osm_aero_linestring' OR table_name = 'osm_aero_polygon') AND timestamp = ts
	    	UNION
	    	SELECT osm_id FROM osm_update
	    	WHERE (table_name = 'osm_aero_linestring' OR table_name = 'osm_aero_polygon') AND timestamp = ts
		), changed_geometries AS (
			SELECT osm_id, timestamp, geometry FROM osm_delete
    		WHERE table_name = 'osm_aero_linestring' OR table_name = 'osm_aero_polygon'
    		UNION
		    SELECT osm_id, geometry FROM layer_aeroway 
		    WHERE timestamp = ts AND osm_id IN created_or_updated_osm_ids
		), changed_tiles AS (
		    SELECT DISTINCT c.osm_id, t.tile_x AS x, t.tile_y AS y, t.tile_z AS z
		    FROM changed_geometries AS c
		    INNER JOIN LATERAL overlapping_tiles(c.geometry, 14) AS t ON true
		)

		SELECT c.x, c.y, c.z FROM aeroway_z12toz14 AS l
		INNER JOIN changed_tiles AS c ON c.osm_id = l.osm_id AND c.z BETWEEN 12 AND 14
	);
END;
$$ LANGUAGE plpgsql;
