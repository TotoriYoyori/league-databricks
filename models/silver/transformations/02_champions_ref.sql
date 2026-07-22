-------------------------------------------------------------------------------------------
-- 01. CLEANING VIEW                          
-------------------------------------------------------------------------------------------
CREATE TEMPORARY VIEW champions_ref_clean AS
SELECT
    TRY_CAST(champion_id AS INT) AS champion_id,
    pascal_to_title_case(champion_name) AS champion_name,
    ai_gen(
        'What is the official League of Legends splash-art title for the champion ' || champion_name || '? Respond with only the title in the exact format "The X", nothing else.'
    ) AS champion_title,
    ldts
FROM STREAM(bronze.champions_ref)
;
-------------------------------------------------------------------------------------------
-- 02. DDL                            
-------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE champions_ref (
    champion_id INT NOT NULL,
    champion_name STRING COMMENT "Display name of the champion as of this version, normalized to Title Case.",
    champion_title STRING COMMENT "AI-generated official lore title (e.g. 'The Virtuoso'). Experimental ONLY!",
    -- CDC Type 2
    __START_AT TIMESTAMP COMMENT "Timestamp this version became active.",
    __END_AT TIMESTAMP COMMENT "Timestamp this version stopped being active (NULL if current).",

    CONSTRAINT ok_champion_name_length EXPECT (LENGTH(champion_name) <= 64),
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