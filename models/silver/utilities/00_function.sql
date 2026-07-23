USE CATALOG league_records;

USE SCHEMA silver;

-------------------------------------------------------------------------------------------
-- STRING OPS
-------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pascal_to_title_case(raw_value STRING)
RETURNS STRING
COMMENT '[silver] Normalizes PascalCase or inconsistently-cased text into Title Case, e.g. TwistedFate -> Twisted Fate.'
RETURN INITCAP(TRIM(
    REGEXP_REPLACE(raw_value, '([a-z])([A-Z])', '\$1 \$2')
))
;

CREATE OR REPLACE FUNCTION safecast_to_int(raw_value STRING)
RETURNS INT 
COMMENT '[silver] Expect and convert numeric-like strings to integer, regardless of decimals (will round up). Null if cannot be converted.'
RETURN TRY_CAST(ROUND(
    TRY_CAST(raw_value AS DOUBLE)
, 0) AS INT)
;

CREATE OR REPLACE FUNCTION valid_num_range(
    num_val DOUBLE, 
    num_min DOUBLE, 
    num_max DOUBLE
)
RETURNS DOUBLE
COMMENT '[silver] Nullifies num_val when outside the valid [num_min, num_max] range.'
RETURN 
    CASE 
        WHEN num_val BETWEEN num_min AND num_max THEN num_val 
        ELSE NULL 
    END
;

CREATE OR REPLACE FUNCTION valid_ts_range(
    ts_val TIMESTAMP, 
    ts_min TIMESTAMP, 
    ts_max TIMESTAMP
)
RETURNS TIMESTAMP
COMMENT '[silver] Nullifies ts_val when outside the valid [ts_min, ts_max] range.'
RETURN 
    CASE 
        WHEN ts_val BETWEEN ts_min AND ts_max THEN ts_val 
        ELSE NULL 
    END
;

CREATE OR REPLACE FUNCTION nullify_caplen(
    raw_value STRING, 
    max_len INT
)
RETURNS STRING
COMMENT '[silver] Nullifies raw_value when LENGTH(raw_value) exceeds max_len.'
RETURN 
    CASE 
        WHEN LENGTH(raw_value) <= max_len THEN raw_value 
        ELSE NULL 
    END
;