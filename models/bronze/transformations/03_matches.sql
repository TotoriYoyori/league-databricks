-------------------------------------------------------------------------------------------
-- 01. DDL                                             
-------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE matches (
    -- Source
    match_id STRING NOT NULL,
    game_duration STRING,
    patch_version STRING,
    winning_team STRING,
    game_date STRING,
    game_version STRING,
    game_mode STRING,
    queue_id STRING,
    region STRING,
    average_rank STRING,
    blue_bans STRING,
    red_bans STRING,
    -- Metadata
    ldts TIMESTAMP NOT NULL,
    file_name STRING NOT NULL,
    rsrc STRING NOT NULL,

    CONSTRAINT bronze_matches_pkey PRIMARY KEY (match_id)
)
COMMENT '[bronze] Raw match summary. Loaded from kaggle_csv/matches volume.'
AS
-------------------------------------------------------------------------------------------
-- 02. READ FROM VOLUME                                           
-------------------------------------------------------------------------------------------
SELECT
    -- Source
    match_id,
    game_duration,
    patch_version,
    winning_team,
    game_date,
    game_version,
    game_mode,
    queue_id,
    region,
    average_rank,
    blue_bans,
    red_bans,
    -- Metadata
    CURRENT_TIMESTAMP() AS ldts,
    _metadata.file_name AS file_name,
    'Kaggle' AS rsrc   
FROM STREAM READ_FILES(
    '/Volumes/${catalog}/${schema}/kaggle_csv/matches/*.csv.gz',
    FORMAT => 'csv',
    HEADER => true,
    DELIMITER => ',',
    QUOTE => '"',
    IGNORELEADINGWHITESPACE => true,
    IGNORETRAILINGWHITESPACE => true,
    SCHEMA => '
        match_id STRING,
        game_duration STRING,
        patch_version STRING,
        winning_team STRING,
        game_date STRING,
        game_version STRING,
        game_mode STRING,
        queue_id STRING,
        region STRING,
        average_rank STRING,
        blue_bans STRING,
        red_bans STRING
    '
)
;