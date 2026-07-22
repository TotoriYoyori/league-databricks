-------------------------------------------------------------------------------------------
-- 01. DDL                                             
-------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE intervals (
    -- ID
    id STRING NOT NULL,
    match_id STRING NOT NULL,
    player_id STRING NOT NULL,
    minute STRING NOT NULL,
    -- Economy
    current_gold STRING,
    total_gold STRING,
    cs STRING,
    jungle_cs STRING,
    xp STRING,
    level STRING,
    -- KDA
    kills STRING,
    deaths STRING,
    assists STRING,
    -- Item slot ID
    item_0 STRING,
    item_1 STRING,
    item_2 STRING,
    item_3 STRING,
    item_4 STRING,
    item_5 STRING,
    item_6 STRING,
    -- Team objectives
    team_kills STRING,
    team_inhibitors STRING,
    team_towers STRING,
    team_dragons_fire STRING,
    team_dragons_water STRING,
    team_dragons_earth STRING,
    team_dragons_air STRING,
    team_dragons_chemtech STRING,
    team_dragons_hextech STRING,
    team_dragons STRING,
    team_barons STRING,
    team_void_grubs STRING,
    team_heralds STRING,
    -- Diffs
    gold_diff STRING,
    xp_diff STRING,
    team_gold_diff STRING,
    -- Metadata
    ldts TIMESTAMP NOT NULL,
    file_name STRING NOT NULL,
    rsrc STRING NOT NULL,

    CONSTRAINT bronze_intervals_pkey PRIMARY KEY (id)
)
COMMENT '[bronze] Raw match interval snapshots. Loaded from kaggle_csv/intervals volume.'
AS
-------------------------------------------------------------------------------------------
-- 02. READ FROM VOLUME                                           
-------------------------------------------------------------------------------------------
SELECT
    -- Source
    id,
    match_id,
    player_id,
    minute,
    -- Economy
    current_gold,
    total_gold,
    cs,
    jungle_cs,
    xp,
    level,
    -- KDA
    kills,
    deaths,
    assists,
    -- Item slot ID
    item_0,
    item_1,
    item_2,
    item_3,
    item_4,
    item_5,
    item_6,
    -- Team objectives
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
    -- Diffs
    gold_diff,
    xp_diff,
    team_gold_diff,
    -- Metadata
    CURRENT_TIMESTAMP() AS ldts,
    _metadata.file_name AS file_name,
    'Kaggle' AS rsrc
FROM STREAM READ_FILES(
    '/Volumes/${catalog}/${schema}/kaggle_csv/intervals/*.csv.gz',
    FORMAT => 'csv',
    HEADER => true,
    DELIMITER => ',',
    QUOTE => '"',
    IGNORELEADINGWHITESPACE => true,
    IGNORETRAILINGWHITESPACE => true,
    SCHEMA => '
        id STRING,
        match_id STRING,
        player_id STRING,
        minute STRING,
        current_gold STRING,
        total_gold STRING,
        cs STRING,
        jungle_cs STRING,
        xp STRING,
        level STRING,
        kills STRING,
        deaths STRING,
        assists STRING,
        item_0 STRING,
        item_1 STRING,
        item_2 STRING,
        item_3 STRING,
        item_4 STRING,
        item_5 STRING,
        item_6 STRING,
        team_kills STRING,
        team_inhibitors STRING,
        team_towers STRING,
        team_dragons_fire STRING,
        team_dragons_water STRING,
        team_dragons_earth STRING,
        team_dragons_air STRING,
        team_dragons_chemtech STRING,
        team_dragons_hextech STRING,
        team_dragons STRING,
        team_barons STRING,
        team_void_grubs STRING,
        team_heralds STRING,
        gold_diff STRING,
        xp_diff STRING,
        team_gold_diff STRING
    '
)
;
