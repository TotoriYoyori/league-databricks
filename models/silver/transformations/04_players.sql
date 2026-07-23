USE CATALOG league_records;

USE SCHEMA silver;

-------------------------------------------------------------------------------------------
-- 01. CLEANING VIEW
-------------------------------------------------------------------------------------------
CREATE TEMPORARY VIEW players_clean AS
SELECT
    UPPER(match_id) AS match_id,
    -- Bound to 1-10
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(participant_id), 
        1, 10
    )::INT AS participant_pos_id,
    -- Normalize 100 -> Blue / 200 -> Red
    CASE team_id
        WHEN '100' THEN 'Blue'
        WHEN '200' THEN 'Red'
        ELSE NULL
    END AS team,
    -- PascalCase -> Title Case + Fix the known 'Fiddle Sticks' naming discrepancy.
    REPLACE(
        league_records.silver.pascal_to_title_case(champion), 
        'Fiddle Sticks', 'Fiddlesticks'
    ) AS champion_name,
    -- Normalized to Title Case, and to standard naming (Top, Jungle, Mid, Bottom, Support)
    CASE
        WHEN UPPER(role) = 'UTILITY' THEN 'Support'
        ELSE INITCAP(role)
    END AS champion_role
FROM STREAM(bronze.players)
;

-------------------------------------------------------------------------------------------
-- 02. DDL (Pure append-only streaming table)
-------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE players (
    -- Key
    match_id STRING NOT NULL,
    participant_pos_id INT NOT NULL COMMENT 'The index position of the player at queue time. 1-5 for Blue side, 6-10 for Red side.',
    team STRING NOT NULL COMMENT 'Blue or Red.',
    -- Description
    champion_name STRING COMMENT 'The name of the champion as recorded in the log, normalized from bronze.',
    champion_role STRING COMMENT 'Resolved role played by the player based on in-game signals.',

    CONSTRAINT valid_match_id EXPECT (match_id IS NOT NULL) ON VIOLATION DROP ROW,
    CONSTRAINT valid_participant_pos_id EXPECT (
        participant_pos_id IS NOT NULL 
        AND participant_pos_id BETWEEN 1 AND 10
    ) ON VIOLATION DROP ROW,
    CONSTRAINT valid_team EXPECT (
        team IS NOT NULL
        AND team IN ('Blue', 'Red')
    ) ON VIOLATION DROP ROW,

    CONSTRAINT silver_players_pkey PRIMARY KEY (match_id, participant_pos_id)
)
CLUSTER BY (match_id, participant_pos_id)
COMMENT '[silver] Classic mode (Summoner''s Rift 5v5, draft queue) summary for individual players per match.'
AS

SELECT *
FROM STREAM(players_clean)
;