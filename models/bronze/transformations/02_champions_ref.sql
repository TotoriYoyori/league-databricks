-------------------------------------------------------------------------------------------
-- 01. DDL                                             
-------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE champions_ref (
    -- Source
    champion_id STRING NOT NULL,
    champion_name STRING,
    -- Metadata
    ldts TIMESTAMP NOT NULL,
    file_name STRING NOT NULL,
    rsrc STRING NOT NULL,

    CONSTRAINT bronze_champions_ref_pkey PRIMARY KEY (champion_id)
)
COMMENT '[bronze] Champion reference lookup. Ingest frequency --> Every patch update.'
AS
-------------------------------------------------------------------------------------------
-- 02. READ FROM VOLUME                                           
-------------------------------------------------------------------------------------------
SELECT
    -- Source
    champion_id,
    champion_name,
    -- Metadata
    CURRENT_TIMESTAMP() AS ldts,
    _metadata.file_name AS file_name,
    'Kaggle' AS rsrc   
FROM STREAM READ_FILES(
    '/Volumes/${catalog}/${schema}/kaggle_csv/champions/*.csv.gz',
    FORMAT => 'csv',
    HEADER => true,
    DELIMITER => ',',
    QUOTE => '"',
    IGNORELEADINGWHITESPACE => true,
    IGNORETRAILINGWHITESPACE => true,
    SCHEMA => '
        champion_id STRING,
        champion_name STRING
    '
)
;
