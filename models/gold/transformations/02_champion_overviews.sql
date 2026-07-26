-------------------------------------------------------------------------------------------
-- DESIGN NOTES:
--     To properly inform win rates, all remakes/unfinished games (game_duration < 300s)
--     are excluded (since LoL remakes occur between 1:30 - 5:00). Other statistics use
--     all matches.
-------------------------------------------------------------------------------------------
CREATE OR REFRESH MATERIALIZED VIEW champion_overviews (
    -- Key
    champion_id INT NOT NULL,
    -- Context
    champion_name STRING COMMENT 'Champion display name (latest version).',
    most_picked_lane STRING COMMENT 'Lane this champion is most often played in, across all matches.',
    primary_lane_share DOUBLE COMMENT 'Share of this champion''s total picks that occurred in most_picked_lane.',
    -- Stats
    global_games_played INT COMMENT 'Total games this champion was picked in, across all matches.',
    global_pick_rate DOUBLE COMMENT 'Share of all matches in which this champion was picked.',
    global_win_rate DOUBLE COMMENT 'Win rate for this champion, excluding remakes/unfinished games (game_duration < 300s).',
    global_ban_rate DOUBLE COMMENT 'Share of all matches in which this champion was banned (blue or red side).',

    CONSTRAINT ok_balance_winrate EXPECT (global_win_rate BETWEEN 0.40 AND 0.60),
    CONSTRAINT ok_balance_banrate EXPECT (global_ban_rate <= 0.50),
    CONSTRAINT ok_balance_pickrate EXPECT (global_pick_rate <= 0.20),

    CONSTRAINT champion_overview_pkey PRIMARY KEY (champion_id)
)
COMMENT '[gold] Champion-level pick/win/ban rate and primary lane.'
AS
-------------------------------------------------------------------------------------------
-- 01. player_match_all / player_match_no_remake
--     Pick/ban/lane stats use ALL matches. Win rate uses no-remake matches only.
-------------------------------------------------------------------------------------------
WITH player_match_all AS (
    SELECT
        mat.match_id,
        ps.champion_name,
        ps.champion_role
    FROM silver.matches AS mat
    JOIN silver.players AS ps
        ON ps.match_id = mat.match_id
),

player_match_no_remake AS (
    SELECT
        ps.champion_name,
        (ps.team = mat.winning_team) AS win
    FROM (
        SELECT * 
        FROM silver.matches
        WHERE game_duration >= 300
    ) AS mat
    JOIN silver.players AS ps
        ON ps.match_id = mat.match_id
),
-------------------------------------------------------------------------------------------
-- 02. champion_pick_stats (all matches) / champion_win_stats (no-remake only)
-------------------------------------------------------------------------------------------
champion_pick_stats AS (
    SELECT
        champion_name,
        COUNT(*)::INT AS global_games_played
    FROM player_match_all
    GROUP BY champion_name
),

champion_win_stats AS (
    SELECT
        champion_name,
        COUNT(*) AS win_eligible_games,
        SUM(CASE WHEN win THEN 1 ELSE 0 END) AS wins
    FROM player_match_no_remake
    WHERE win IS NOT NULL
    GROUP BY champion_name
),
-------------------------------------------------------------------------------------------
-- 03. primary_lane
-------------------------------------------------------------------------------------------
primary_lane AS (
    SELECT champion_name, most_picked_lane, primary_lane_share
    FROM (
        SELECT
            champion_name,
            champion_role AS most_picked_lane,
            COUNT(*) AS pick_count,
            ROW_NUMBER() OVER (
                PARTITION BY champion_name
                ORDER BY COUNT(*) DESC, champion_role  -- Tiebreaker for if same count
            ) AS rn,
            ROUND(
                COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY champion_name)
            , 4) AS primary_lane_share
        FROM player_match_all
        GROUP BY champion_name, champion_role
    )
    WHERE rn = 1
),
-------------------------------------------------------------------------------------------
-- 04. all_bans -> ban_counts
-------------------------------------------------------------------------------------------
all_bans AS (
    SELECT DISTINCT match_id, champion_id
    FROM (
        SELECT match_id, EXPLODE(blue_bans) AS champion_id
        FROM silver.matches
            UNION ALL
        SELECT match_id, EXPLODE(red_bans) AS champion_id
        FROM silver.matches
    )
    WHERE champion_id != 0
),

ban_counts AS (
    SELECT champion_id, COUNT(*) AS games_banned
    FROM all_bans
    GROUP BY champion_id
),

-------------------------------------------------------------------------------------------
-- 05. total_games_all -> calc_aggs
-------------------------------------------------------------------------------------------
total_games_all AS (
    SELECT COUNT(*) AS total_games
    FROM silver.matches
),

calc_aggs AS (
    SELECT
        cr.champion_id,
        cr.champion_name,
        pl.most_picked_lane,
        pl.primary_lane_share,
        COALESCE(cps.global_games_played, 0) AS global_games_played,
        ROUND(
            COALESCE(cps.global_games_played, 0) / tga.total_games
        , 4) AS global_pick_rate,
        ROUND(
            cws.wins / cws.win_eligible_games
        , 4) AS global_win_rate,
        ROUND(
            COALESCE(bc.games_banned, 0) / tga.total_games
        , 4) AS global_ban_rate
    FROM (
        SELECT * 
        FROM silver.champions_ref
        WHERE __END_AT IS NULL  -- current version only
    ) AS cr
    LEFT JOIN champion_pick_stats AS cps
        ON cps.champion_name = cr.champion_name
    LEFT JOIN champion_win_stats AS cws
        ON cws.champion_name = cr.champion_name
    LEFT JOIN primary_lane AS pl
        ON pl.champion_name = cr.champion_name
    LEFT JOIN ban_counts AS bc
        ON bc.champion_id = cr.champion_id
    CROSS JOIN total_games_all AS tga
)
-------------------------------------------------------------------------------------------
-- Select all above for complete query
-------------------------------------------------------------------------------------------
SELECT *
FROM calc_aggs
WHERE champion_id != 0
;