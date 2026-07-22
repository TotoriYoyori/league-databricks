-------------------------------------------------------------------------------------------
-- 01. DDL                                             
-------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE players (
    -- Source
    id STRING NOT NULL,
    match_id STRING NOT NULL,
    participant_id STRING,
    team_id STRING,
    champion STRING,
    role STRING,
    individual_position STRING,
    -- Metadata
    ldts TIMESTAMP NOT NULL,
    file_name STRING NOT NULL,
    rsrc STRING NOT NULL,

    CONSTRAINT bronze_players_pkey PRIMARY KEY (id)
)
COMMENT '[bronze] Raw player summary. Loaded from kaggle_csv/players volume.'
AS
-------------------------------------------------------------------------------------------
-- 02. READ FROM VOLUME                                           
-------------------------------------------------------------------------------------------
SELECT
    -- Source
    id,
    match_id,
    participant_id,
    team_id,
    champion,
    role,
    individual_position,
    -- Metadata
    CURRENT_TIMESTAMP() AS ldts,
    _metadata.file_name AS file_name,
    'Kaggle' AS rsrc
FROM STREAM READ_FILES(
    '/Volumes/${catalog}/${schema}/kaggle_csv/players/*.csv.gz',
    FORMAT => 'csv',
    HEADER => true,
    DELIMITER => ',',
    QUOTE => '"',
    IGNORELEADINGWHITESPACE => true,
    IGNORETRAILINGWHITESPACE => true,
    SCHEMA => '
        id STRING,
        match_id STRING,
        participant_id STRING,
        team_id STRING,
        champion STRING,
        role STRING,
        individual_position STRING
    '
)
;
