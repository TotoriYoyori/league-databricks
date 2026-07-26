-------------------------------------------------------------------------------------------
-- DESIGN NOTES:
--     winning_gold_diff reports the gold differential of whichever team won, so it's always
--     framed as "the winner's gold lead" rather than "blue's gold lead."
-------------------------------------------------------------------------------------------
CREATE OR REFRESH MATERIALIZED VIEW matchend_pivot_teamstats (
    -- Key
    match_id STRING NOT NULL,
    -- Context
    game_duration INT COMMENT 'Match duration in seconds.',
    game_date TIMESTAMP COMMENT 'Match end timestamp.',
    game_version STRING COMMENT 'Game client version string.',
    winning_team STRING COMMENT 'BLUE or RED.',
    average_rank STRING COMMENT 'Average rank of match participants, Title Cased.',
    -- Stats (as of last logged interval, see known limitations)
    blue_kills INT COMMENT 'Blue team total kills at last logged interval.',
    red_kills INT COMMENT 'Red team total kills at last logged interval.',
    blue_towers INT COMMENT 'Blue team towers destroyed at last logged interval.',
    red_towers INT COMMENT 'Red team towers destroyed at last logged interval.',
    blue_inhibitors INT COMMENT 'Blue team inhibitors destroyed at last logged interval.',
    red_inhibitors INT COMMENT 'Red team inhibitors destroyed at last logged interval.',
    blue_dragons INT COMMENT 'Blue team dragons taken at last logged interval.',
    red_dragons INT COMMENT 'Red team dragons taken at last logged interval.',
    blue_void_grubs INT COMMENT 'Blue team void grubs taken at last logged interval.',
    red_void_grubs INT COMMENT 'Red team void grubs taken at last logged interval.',
    blue_heralds INT COMMENT 'Blue team Rift Heralds taken at last logged interval.',
    red_heralds INT COMMENT 'Red team Rift Heralds taken at last logged interval.',
    blue_barons INT COMMENT 'Blue team Baron Nashors taken at last logged interval.',
    red_barons INT COMMENT 'Red team Baron Nashors taken at last logged interval.',
    winning_gold_diff INT COMMENT 'Gold differential of the winning_team specifically. A winning team at a gold loss reports a negative value.',
    -- Data quality signal
    unlogged_duration INT COMMENT 'Seconds between the last logged 5-minute interval and actual match end (game_duration).',

    CONSTRAINT match_team_stats_summary_pkey PRIMARY KEY (match_id)
)
CLUSTER BY (match_id)
COMMENT '[gold] Match-grain summary with team statistics.'
AS
-------------------------------------------------------------------------------------------
-- 00. team_final -> Deduplicate team stats for each match ends.
-------------------------------------------------------------------------------------------
WITH team_minute_dedup AS (
    SELECT DISTINCT
        match_id,
        team,
        minute,
        team_kills,
        team_towers,
        team_inhibitors,
        team_dragons,
        team_void_grubs,
        team_heralds,
        team_barons,
        team_gold_diff
    FROM silver.intervals
),

team_final AS (
    SELECT * EXCEPT(rn)
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY match_id, team
                ORDER BY minute DESC
            ) AS rn
        FROM team_minute_dedup
    )
    WHERE rn = 1
),
-------------------------------------------------------------------------------------------
-- 01. pivot_team_stats
--     -> Capture team stats only at last snapshot interval and pivot them for wide view.
--     intervals is player-minute grain.
-------------------------------------------------------------------------------------------
pivot_team_stats AS (
    SELECT
        match_id,
        MAX(minute) AS last_logged_minute,
        MAX(CASE WHEN team = 'BLUE' THEN team_kills END) AS blue_kills,
        MAX(CASE WHEN team = 'RED' THEN team_kills END) AS red_kills,
        MAX(CASE WHEN team = 'BLUE' THEN team_towers END) AS blue_towers,
        MAX(CASE WHEN team = 'RED' THEN team_towers END) AS red_towers,
        MAX(CASE WHEN team = 'BLUE' THEN team_inhibitors END) AS blue_inhibitors,
        MAX(CASE WHEN team = 'RED' THEN team_inhibitors END) AS red_inhibitors,
        MAX(CASE WHEN team = 'BLUE' THEN team_dragons END) AS blue_dragons,
        MAX(CASE WHEN team = 'RED' THEN team_dragons END) AS red_dragons,
        MAX(CASE WHEN team = 'BLUE' THEN team_void_grubs END) AS blue_void_grubs,
        MAX(CASE WHEN team = 'RED' THEN team_void_grubs END) AS red_void_grubs,
        MAX(CASE WHEN team = 'BLUE' THEN team_heralds END) AS blue_heralds,
        MAX(CASE WHEN team = 'RED' THEN team_heralds END) AS red_heralds,
        MAX(CASE WHEN team = 'BLUE' THEN team_barons END) AS blue_barons,
        MAX(CASE WHEN team = 'RED' THEN team_barons END) AS red_barons,
        MAX(CASE WHEN team = 'BLUE' THEN team_gold_diff END) AS blue_gold_diff,
        MAX(CASE WHEN team = 'RED' THEN team_gold_diff END) AS red_gold_diff
    FROM team_final
    GROUP BY match_id
),

-------------------------------------------------------------------------------------------
-- 02. match_stats_summary_cte
-------------------------------------------------------------------------------------------
match_stats_summary_cte AS (
    SELECT
        -- Primary key
        p.match_id,
        -- Context
        m.game_duration,
        m.game_date,
        m.game_version,
        m.winning_team,
        m.average_rank,
        -- Stats
        p.blue_kills,
        p.red_kills,
        p.blue_towers,
        p.red_towers,
        p.blue_inhibitors,
        p.red_inhibitors,
        p.blue_dragons,
        p.red_dragons,
        p.blue_void_grubs,
        p.red_void_grubs,
        p.blue_heralds,
        p.red_heralds,
        p.blue_barons,
        p.red_barons,
        -- Gold diff of the winning team only
        CASE
            WHEN m.winning_team = 'BLUE' THEN p.blue_gold_diff
            WHEN m.winning_team = 'RED'  THEN p.red_gold_diff
        END AS winning_gold_diff,
        -- Unlogged duration for data quality check
        GREATEST(m.game_duration - p.last_logged_minute * 60, 0) AS unlogged_duration
    FROM pivot_team_stats AS p
    JOIN silver.matches AS m
        ON p.match_id = m.match_id
)

-------------------------------------------------------------------------------------------
-- Select all above for complete query
-------------------------------------------------------------------------------------------
SELECT *
FROM match_stats_summary_cte
;
