USE CATALOG league_records;

USE SCHEMA silver;

-------------------------------------------------------------------------------------------
-- 01. CLEANING VIEW                          
-------------------------------------------------------------------------------------------
CREATE TEMPORARY VIEW champions_ref_clean AS
SELECT
    league_records.silver.safecast_to_int(champion_id) AS champion_id,
    REPLACE(
        league_records.silver.pascal_to_title_case(champion_name),
        'Fiddle Sticks', 'Fiddlesticks'
    ) AS champion_name,
    ldts
FROM STREAM(bronze.champions_ref)
;
-------------------------------------------------------------------------------------------
-- 02. DDL                            
-------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE champions_ref (
    champion_id INT NOT NULL,
    champion_name STRING COMMENT 'Display name of the champion as of this version, normalized to Title Case.',
    -- CDC Type 2
    __START_AT TIMESTAMP COMMENT 'Timestamp this version became active.',
    __END_AT TIMESTAMP COMMENT 'Timestamp this version stopped being active (NULL if current).',

    CONSTRAINT valid_champion_id EXPECT (champion_id IS NOT NULL) ON VIOLATION DROP ROW,
    
    CONSTRAINT silver_champions_ref_pkey PRIMARY KEY (champion_id, __START_AT TIMESERIES)
)
COMMENT '[silver] Champion reference lookup, with SCD Type 2 change history across patches.'
;
-------------------------------------------------------------------------------------------
-- 03. TYPE 2 CDC FLOW                       
-------------------------------------------------------------------------------------------
CREATE FLOW champions_ref_cdc_flow
AS AUTO CDC INTO champions_ref
FROM STREAM(champions_ref_clean)
    KEYS (champion_id)
    SEQUENCE BY ldts
    COLUMNS * EXCEPT (ldts)
    STORED AS SCD TYPE 2
;