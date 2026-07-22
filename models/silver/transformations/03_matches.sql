-------------------------------------------------------------------------------------------
-- 01. CLEANING VIEW
-------------------------------------------------------------------------------------------
CREATE TEMPORARY VIEW matches_clean AS
SELECT
    UPPER(match_id) AS match_id,
    -- Normalize team to readable format: 100 -> Blue, 200 -> Red
    CASE winning_team
        WHEN '100' THEN 'Blue'
        WHEN '200' THEN 'Red'
        ELSE NULL
    END AS winning_team,
    -- Double (float/int) -> round to whole seconds -> cast back to INT
    TRY_CAST(ROUND(
        TRY_CAST(game_duration AS DOUBLE)
    , 0) AS INT) AS game_duration,
    TRY_CAST(game_date AS TIMESTAMP) AS game_date,
    game_version,
    INITCAP(average_rank) AS average_rank,
    -- Split ban sequence into array of ints, -1 sentinel replaced with 0
    TRANSFORM(
        SPLIT(blue_bans, ','),
        x -> CASE WHEN TRY_CAST(x AS INT) = -1 THEN 0 ELSE TRY_CAST(x AS INT) END
    ) AS blue_bans,
    TRANSFORM(
        SPLIT(red_bans, ','),
        x -> CASE WHEN TRY_CAST(x AS INT) = -1 THEN 0 ELSE TRY_CAST(x AS INT) END
    ) AS red_bans
FROM STREAM(bronze.matches)
;

-------------------------------------------------------------------------------------------
-- 02. DDL (Pure append-only streaming table)
-------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE matches (
    match_id STRING NOT NULL,
    winning_team STRING NOT NULL COMMENT 'Blue or Red. Not null for joins.',
    game_duration INT COMMENT 'Match duration in seconds.',
    game_date TIMESTAMP COMMENT 'Match end timestamp.',
    game_version STRING COMMENT 'Game client version string.',
    average_rank STRING COMMENT 'Average rank of match participants, Title Cased.',
    blue_bans ARRAY<INT> COMMENT 'Blue team champion ban sequence.',
    red_bans ARRAY<INT> COMMENT 'Red team champion ban sequence.',

    CONSTRAINT valid_match_id EXPECT (match_id IS NOT NULL) ON VIOLATION DROP ROW,
    CONSTRAINT valid_winning_team EXPECT (winning_team IS NOT NULL) ON VIOLATION DROP ROW,

    CONSTRAINT ok_game_duration EXPECT (game_duration BETWEEN 0 AND 3 * 60 * 60),
    CONSTRAINT ok_game_date EXPECT (game_date BETWEEN TIMESTAMP '2009-10-27 00:00:00' AND CURRENT_TIMESTAMP()),
    CONSTRAINT ok_game_version EXPECT (game_version RLIKE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'),

    CONSTRAINT silver_matches_pkey PRIMARY KEY (match_id)
)
COMMENT '[silver] Classic mode (Summoner''s Rift 5v5, draft queue) match summary.'
AS
SELECT *
FROM STREAM(matches_clean)
;