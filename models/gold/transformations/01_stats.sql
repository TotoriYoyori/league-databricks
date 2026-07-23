-------------------------------------------------------------------------------------------
-- KNOWN LIMITATIONS:
--     a. "End of match" stats (kills/deaths/assists/cs/total_gold/item_build/level) reflect
--     the LAST LOGGED INTERVAL, not the literal game-end state. Source data is sampled
--     every 5 minutes, so up to ~4-5 minutes of unrecorded state (item purchases, kills,
--     gold gain) may be missing between the last logged interval and actual end time.
--     b. unlogged_duration is added to inform consumers how stale each record can be.
--
-- FUTURE IMPROVEMENTS:
--     If/when an end-of-match participant snapshot becomes available from the data source
--     (separate from the timeline/interval endpoint), prefer that for final build and
--     final KDA/gold specifically, and keep interval data only for time-series analysis.
-------------------------------------------------------------------------------------------
CREATE OR REFRESH MATERIALIZED VIEW stats_summary (
    -- Key
    match_id STRING NOT NULL COMMENT 'Unique match identifier.',
    participant_pos_id INT NOT NULL COMMENT 'Player position 1-10.',
    -- Context
    game_duration INT COMMENT 'Match duration in seconds.',
    team STRING COMMENT 'Blue or Red.',
    win BOOLEAN COMMENT 'Whether this player''s team won the match.',
    champion_name STRING COMMENT 'Champion played.',
    champion_role STRING COMMENT 'Resolved role played, based on in-game signals.',
    -- Stats (as of last logged interval, see known limitations)
    level INT COMMENT 'End-of-match champion level.',
    kills INT COMMENT 'End-of-match kills.',
    deaths INT COMMENT 'End-of-match deaths.',
    assists INT COMMENT 'End-of-match assists.',
    cs INT COMMENT 'End-of-match combined lane + jungle creep score.',
    total_gold INT COMMENT 'End-of-match cumulative gold earned.',
    -- Build
    item_build ARRAY<STRING> COMMENT 'End-of-match sorted item names.',
    -- Data quality signal
    unlogged_duration INT COMMENT 'Seconds between this player''s last logged 5-minute interval and actual match end (game_duration). Indicates how stale this record can be.',

    CONSTRAINT player_stats_summary_pkey PRIMARY KEY (match_id, participant_pos_id)
)
CLUSTER BY (match_id, participant_pos_id)
COMMENT '[gold] One end-of-match player stat row per (match_id, participant_pos_id), defined as last-logged interval.'
AS

WITH final_snapshot AS (
    SELECT *
    FROM silver.intervals
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY match_id, participant_pos_id
        ORDER BY minute DESC
    ) = 1
),

match_stats_at_end AS (
    SELECT
        match_id,
        participant_pos_id,
        minute,
        level,
        kills,
        deaths,
        assists,
        (cs + jungle_cs) AS cs,
        total_gold
    FROM final_snapshot
),
-------------------------------------------------------------------------------------------
-- item_id_array -> flattened_item_ids -> named_item_build
-------------------------------------------------------------------------------------------
item_id_array AS (
    SELECT
        match_id,
        participant_pos_id,
        FILTER(
            ARRAY(item_0, item_1, item_2, item_3, item_4, item_5, item_6),
            x -> x IS NOT NULL
        ) AS item_ids
    FROM final_snapshot
),

flattened_item_ids AS (
    SELECT
        match_id,
        participant_pos_id,
        explode(item_ids) AS item_id
    FROM item_id_array
),

named_item_build AS (
    SELECT fi.match_id, fi.participant_pos_id,
        SORT_ARRAY(COLLECT_LIST(ir.item_name)) AS item_build
    FROM flattened_item_ids AS fi
    LEFT JOIN silver.items_ref AS ir
        ON ir.item_id = fi.item_id
        AND ir.__END_AT IS NULL
    GROUP BY fi.match_id, fi.participant_pos_id
)
-------------------------------------------------------------------------------------------
-- Join interval snapshot with matches, players, and resolved item-name build array
-------------------------------------------------------------------------------------------
SELECT
    se.match_id,
    se.participant_pos_id,
    mat.game_duration,
    ps.team,
    (ps.team = mat.winning_team) AS win,
    ps.champion_name,
    ps.champion_role,
    se.level,
    se.kills,
    se.deaths,
    se.assists,
    se.cs,
    se.total_gold,
    nb.item_build,
    GREATEST(mat.game_duration - se.minute * 60, 0) AS unlogged_duration
FROM match_stats_at_end AS se
JOIN silver.matches AS mat
    ON mat.match_id = se.match_id
JOIN silver.players AS ps
    ON ps.match_id = se.match_id
    AND ps.participant_pos_id = se.participant_pos_id
LEFT JOIN named_item_build AS nb
    ON nb.match_id = se.match_id
    AND nb.participant_pos_id = se.participant_pos_id
;
