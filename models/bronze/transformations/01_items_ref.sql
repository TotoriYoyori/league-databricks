-------------------------------------------------------------------------------------------
-- 01. DDL                                             
-------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE items_ref (
    -- Source
    item_id STRING NOT NULL,
    item_name STRING,
    item_category STRING,
    -- Metadata
    ldts TIMESTAMP NOT NULL,
    file_name STRING NOT NULL,
    rsrc STRING NOT NULL,
    
    CONSTRAINT bronze_items_ref_pkey PRIMARY KEY (item_id)
)
COMMENT '[bronze] Item reference lookup. Ingest frequency --> Every patch update.'
AS
-------------------------------------------------------------------------------------------
-- 02. READ FROM VOLUME                                           
-------------------------------------------------------------------------------------------
SELECT
    -- Source
    item_id,
    item_name,
    item_category,
    -- Metadata
    CURRENT_TIMESTAMP() AS ldts,
    _metadata.file_name AS file_name,
    'Kaggle' AS rsrc
FROM STREAM READ_FILES(
    '/Volumes/${catalog}/${schema}/kaggle_csv/items/*.csv.gz',
    FORMAT => 'csv',
    HEADER => true,
    DELIMITER => ',',
    QUOTE => '"',
    IGNORELEADINGWHITESPACE => true,
    IGNORETRAILINGWHITESPACE => true,
    SCHEMA => '
        item_id STRING, 
        item_name STRING, 
        item_category STRING
    '
)
;
