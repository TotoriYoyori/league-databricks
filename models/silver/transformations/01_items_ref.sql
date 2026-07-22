-------------------------------------------------------------------------------------------
-- 01. CLEANING VIEW                         
-------------------------------------------------------------------------------------------
CREATE TEMPORARY VIEW items_ref_clean AS
SELECT
    TRY_CAST(item_id AS INT) AS item_id,
    item_name,
    item_category,
    ldts
FROM STREAM(bronze.items_ref)
;
-------------------------------------------------------------------------------------------
-- 02. DDL                        
-------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE items_ref (
    item_id INT NOT NULL,
    item_name STRING COMMENT "Display name of the item as of this version.",
    item_category STRING COMMENT "Category the item belonged to as of this version.",
    -- CDC Type 2
    __START_AT TIMESTAMP COMMENT "Timestamp this version became active.",
    __END_AT TIMESTAMP COMMENT "Timestamp this version stopped being active (NULL if current).",

    CONSTRAINT ok_item_name_length EXPECT (LENGTH(item_name) <= 255),
    CONSTRAINT ok_item_category_length EXPECT (LENGTH(item_category) <= 255),
    CONSTRAINT valid_item_id EXPECT (item_id IS NOT NULL) ON VIOLATION DROP ROW,

    CONSTRAINT silver_items_ref_pkey PRIMARY KEY (item_id, __START_AT TIMESERIES)
)
COMMENT '[silver] Item reference lookup, with SCD Type 2 change history across patches.'
;
-------------------------------------------------------------------------------------------
-- 03. TYPE 2 CDC FLOW                     
-------------------------------------------------------------------------------------------
CREATE FLOW items_ref_cdc_flow
AS AUTO CDC INTO items_ref
FROM STREAM(items_ref_clean)
    KEYS (item_id)
    SEQUENCE BY ldts
    COLUMNS * EXCEPT (ldts)
    STORED AS SCD TYPE 2
;