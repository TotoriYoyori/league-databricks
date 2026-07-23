USE CATALOG league_records;

USE SCHEMA silver;

-------------------------------------------------------------------------------------------
-- 01. CLEANING VIEW
-------------------------------------------------------------------------------------------
CREATE TEMPORARY VIEW intervals_clean AS
SELECT
    UPPER(match_id) AS match_id,
    -- player_id 3210 -> participant_pos_id 10 // player_id 3156 -> participant_pos_id 6
    ((
        league_records.silver.safecast_to_int(player_id) - 1
    ) % 10) + 1 AS participant_pos_id,
    -- Player 1-5 -> Blue // Player 6-10 -> Red
    CASE
        WHEN ((league_records.silver.safecast_to_int(player_id) - 1) % 10) + 1 BETWEEN 1 AND 5 THEN 'Blue'
        WHEN ((league_records.silver.safecast_to_int(player_id) - 1) % 10) + 1 BETWEEN 6 AND 10 THEN 'Red'
        ELSE NULL
    END AS team,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(minute), 
        0, 10000
    )::INT AS minute,
    -- Economy
    league_records.silver.safecast_to_int(current_gold) AS current_gold,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(total_gold), 
        0, 1000000000
    )::INT AS total_gold,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(cs), 
        0, 10000
    )::INT AS cs,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(jungle_cs), 
        0, 10000
    )::INT AS jungle_cs,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(xp), 
        0, 1000000000
    )::INT AS xp,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(level), 
        0, 20
    )::INT AS level,
    -- KDA
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(kills), 
        0, 1000
    )::INT AS kills,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(deaths), 
        0, 1000
    )::INT AS deaths,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(assists), 
        0, 1000
    )::INT AS assists,
    -- Itemization: 0 means no item, nullify
    NULLIF(league_records.silver.safecast_to_int(item_0), 0) AS item_0,
    NULLIF(league_records.silver.safecast_to_int(item_1), 0) AS item_1,
    NULLIF(league_records.silver.safecast_to_int(item_2), 0) AS item_2,
    NULLIF(league_records.silver.safecast_to_int(item_3), 0) AS item_3,
    NULLIF(league_records.silver.safecast_to_int(item_4), 0) AS item_4,
    NULLIF(league_records.silver.safecast_to_int(item_5), 0) AS item_5,
    NULLIF(league_records.silver.safecast_to_int(item_6), 0) AS item_6,
    -- Team's objectives
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(team_kills), 
        0, 10000
    )::INT AS team_kills,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(team_inhibitors), 
        0, 100
    )::INT AS team_inhibitors,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(team_towers), 
        0, 100
    )::INT AS team_towers,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(team_dragons_fire), 
        0, 4
    )::INT AS team_dragons_fire,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(team_dragons_water), 
        0, 4
    )::INT AS team_dragons_water,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(team_dragons_earth), 
        0, 4
    )::INT AS team_dragons_earth,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(team_dragons_air), 
        0, 4
    )::INT AS team_dragons_air,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(team_dragons_chemtech), 
        0, 4
    )::INT AS team_dragons_chemtech,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(team_dragons_hextech), 
        0, 4
    )::INT AS team_dragons_hextech,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(team_dragons), 
        0, 100
    )::INT AS team_dragons,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(team_barons), 
        0, 100
    )::INT AS team_barons,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(team_void_grubs), 
        0, 100
    )::INT AS team_void_grubs,
    league_records.silver.valid_num_range(
        league_records.silver.safecast_to_int(team_heralds), 
        0, 100
    )::INT AS team_heralds,
    -- Diffs (no range clamp, matches Snowflake original)
    league_records.silver.safecast_to_int(gold_diff) AS gold_diff,
    league_records.silver.safecast_to_int(xp_diff) AS xp_diff,
    league_records.silver.safecast_to_int(team_gold_diff) AS team_gold_diff
FROM STREAM(bronze.intervals)
;

-------------------------------------------------------------------------------------------
-- 02. INTERVALS (Streaming table, wide: player-minute grain with team stats attached)
-------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE intervals (
    -- Key
    match_id STRING NOT NULL COMMENT 'Unique match identifier.',
    participant_pos_id INT NOT NULL COMMENT 'Player position 1-10, derived from raw player_id.',
    team STRING NOT NULL COMMENT 'Blue or Red.',
    minute INT NOT NULL COMMENT 'Minute mark of this snapshot, expected in 5-minute intervals.',
    -- Economy
    current_gold INT COMMENT 'Unspent gold on hand at this minute mark.',
    total_gold INT COMMENT 'Cumulative gold earned by this minute mark.',
    cs INT COMMENT 'Minion/lane creep score at this minute mark.',
    jungle_cs INT COMMENT 'Jungle creep score at this minute mark.',
    xp INT COMMENT 'Cumulative experience at this minute mark.',
    level INT COMMENT 'Champion level at this minute mark.',
    -- KDA
    kills INT COMMENT 'Player kills at this minute mark.',
    deaths INT COMMENT 'Player deaths at this minute mark.',
    assists INT COMMENT 'Player assists at this minute mark.',
    -- Itemization
    item_0 INT COMMENT 'Item in inventory slot 0.',
    item_1 INT COMMENT 'Item in inventory slot 1.',
    item_2 INT COMMENT 'Item in inventory slot 2.',
    item_3 INT COMMENT 'Item in inventory slot 3.',
    item_4 INT COMMENT 'Item in inventory slot 4.',
    item_5 INT COMMENT 'Item in inventory slot 5.',
    item_6 INT COMMENT 'Item in inventory slot 6.',
    -- Player diffs
    gold_diff INT COMMENT '(Player gold - their lane opponent gold) at this minute mark.',
    xp_diff INT COMMENT '(Player XP - their lane opponent XP) at this minute mark.',
    -- Team's objectives (duplicated across the 5 players sharing a team/minute)
    team_kills INT COMMENT 'Team total kills at this minute mark.',
    team_inhibitors INT COMMENT 'Team inhibitors destroyed at this minute mark.',
    team_towers INT COMMENT 'Team towers destroyed at this minute mark.',
    team_dragons_fire INT COMMENT 'Infernal (fire) dragons taken by this team.',
    team_dragons_water INT COMMENT 'Ocean (water) dragons taken by this team.',
    team_dragons_earth INT COMMENT 'Mountain (earth) dragons taken by this team.',
    team_dragons_air INT COMMENT 'Cloud (air) dragons taken by this team.',
    team_dragons_chemtech INT COMMENT 'Chemtech dragons taken by this team.',
    team_dragons_hextech INT COMMENT 'Hextech dragons taken by this team.',
    team_dragons INT COMMENT 'Total dragons of any element taken by this team.',
    team_barons INT COMMENT 'Baron Nashors taken by this team.',
    team_void_grubs INT COMMENT 'Void Grubs taken by this team.',
    team_heralds INT COMMENT 'Rift Heralds taken by this team.',
    team_gold_diff INT COMMENT '(Team gold - enemy team gold) at this minute mark.',

    CONSTRAINT valid_match_id EXPECT (match_id IS NOT NULL) ON VIOLATION DROP ROW,
    CONSTRAINT valid_participant_pos_id EXPECT (
        participant_pos_id IS NOT NULL
        AND participant_pos_id BETWEEN 1 AND 10
    ) ON VIOLATION DROP ROW,
    CONSTRAINT valid_team EXPECT (
        team IS NOT NULL 
        AND team IN ('Blue', 'Red')
    ) ON VIOLATION DROP ROW,
    CONSTRAINT valid_minute EXPECT (minute IS NOT NULL) ON VIOLATION DROP ROW,

    CONSTRAINT ok_interval_of_5 EXPECT (minute % 5 = 0),

    CONSTRAINT intervals_pkey PRIMARY KEY (match_id, participant_pos_id, minute)
)
CLUSTER BY (match_id, participant_pos_id, minute)
COMMENT '[silver] Classic mode (Summoner''s Rift 5v5, draft queue) player-minute grain interval snapshots, with team-level objective stats attached.'
AS

SELECT
    match_id, 
    participant_pos_id, 
    team, 
    minute, 
    current_gold, 
    total_gold, 
    cs, 
    jungle_cs,
    xp, 
    level, 
    kills, 
    deaths, 
    assists, 
    item_0, 
    item_1, 
    item_2, 
    item_3, 
    item_4, 
    item_5,
    item_6, 
    gold_diff, 
    xp_diff,
    team_kills,
    team_inhibitors,
    team_towers,
    team_dragons_fire,
    team_dragons_water,
    team_dragons_earth,
    team_dragons_air,
    team_dragons_chemtech,
    team_dragons_hextech,
    team_dragons,
    team_barons,
    team_void_grubs,
    team_heralds,
    team_gold_diff
FROM STREAM(intervals_clean)
;
