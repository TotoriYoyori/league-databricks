--------------------------------------------------
-- 00. Create catalog
--------------------------------------------------
CREATE CATALOG IF NOT EXISTS league_records
COMMENT 'League of Legends match analytics, sourced from Kaggle.'
;
--------------------------------------------------
-- 01. Create bronze artifacts
--------------------------------------------------
CREATE SCHEMA IF NOT EXISTS league_records.bronze
COMMENT 'Bronze layer, ingested as is from source with metadata.'
;

CREATE VOLUME IF NOT EXISTS league_records.bronze.kaggle_csv
COMMENT 'Volumes to store raw .csv files from source.'
;
--------------------------------------------------
-- 02. Create silver artifacts
--------------------------------------------------
CREATE SCHEMA IF NOT EXISTS league_records.silver
COMMENT 'Silver layer, transformed and deduped from bronze.'
;
--------------------------------------------------
-- 03. Create gold artifacts
--------------------------------------------------
CREATE SCHEMA IF NOT EXISTS league_records.gold
COMMENT 'Gold layer, aggregated and ready for end users consumption.'
;
--------------------------------------------------
-- 04. Verify above
--------------------------------------------------
SELECT 
    schema_name AS schema,
    comment, 
    created,
    EXTRACT(MINUTE FROM CURRENT_TIMESTAMP() - last_altered) AS last_altered_mins_ago
FROM league_records.information_schema.schemata
;
