-------------------------------------------------------------------------------------------
-- DESIGN NOTES:
--     Since the source logged player data does not record champion as their base ID, but as their displayed
--     name, this makes it very brittle for downstream join. This view keeps track any player data
--     record that has champion name that does not join back to the champion ref table, along with
--     ingestion metadata from Bronze to pinpoint the exact date and source of the problematic data.
-------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW _noref_champion_name (
    noref_src_champion_name COMMENT 'Normalized champion_name from silver.players that did not resolve against silver.champions_ref (current version).',
    ldts COMMENT 'Bronze ingestion load timestamp for the source row.',
    file_name COMMENT 'Bronze source file name for the source row.',
    rsrc COMMENT 'Bronze record source identifier for the source row.'
)
COMMENT '[silver] Data quality view: player rows whose champion_name cannot be resolved against the current version of champions_ref, with bronze ingestion metadata for traceability.'
AS
-------------------------------------------------------------------------------------------
-- Flag rows in logged player data (silver.players) that cannot be resolved to a 
-- current ref champion name (silver.champions_ref).
-------------------------------------------------------------------------------------------
SELECT 
    q.champion_name AS noref_src_champion_name,
    src.ldts,
    src.file_name,
    src.rsrc
FROM (
    SELECT 
        p.match_id,
        p.participant_pos_id,
        p.champion_name
    FROM silver.players AS p
    LEFT JOIN (
        SELECT champion_name
        FROM silver.champions_ref
        WHERE __END_AT IS NULL
    ) AS ref
        ON ref.champion_name = p.champion_name
    WHERE ref.champion_name IS NULL
) AS q
JOIN bronze.players AS src
    ON src.match_id = q.match_id
    AND src.participant_id = q.participant_pos_id
;