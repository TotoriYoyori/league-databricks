import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _common as common

# --------------- 01. Constants ---------------
SCHEMA = "silver"

STATEMENTS = [
    # ----- String ops: PascalCase -> Title Case
    """
    CREATE OR REPLACE FUNCTION pascal_to_title_case(raw_value STRING)
    RETURNS STRING
    COMMENT '[silver] Normalizes PascalCase or inconsistently-cased text into Title Case, e.g. TwistedFate -> Twisted Fate.'
    RETURN INITCAP(TRIM(
        REGEXP_REPLACE(raw_value, '([a-z])([A-Z])', '\\$1 \\$2')
    ))
    """,
    # ----- String ops: safe numeric-string to int
    """
    CREATE OR REPLACE FUNCTION safecast_to_int(raw_value STRING)
    RETURNS INT
    COMMENT '[silver] Expect and convert numeric-like strings to integer, regardless of decimals (will round up). Null if cannot be converted.'
    RETURN TRY_CAST(ROUND(
        TRY_CAST(raw_value AS DOUBLE)
    , 0) AS INT)
    """,
    # ----- Range validation: numeric
    """
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
    """,
    # ----- Range validation: timestamp
    """
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
    """,
    # ----- String ops: length-based nullification
    """
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
    """,
]


# --------------- 02. Main ---------------
if __name__ == "__main__":
    print("---------- Resolving SQL warehouse ----------")
    warehouse_id = common.resolve_running_warehouse()

    print(f"\n---------- Creating UDFs in {common.CATALOG}.{SCHEMA} ----------")
    for stmt in STATEMENTS:
        common.run_statement(warehouse_id, stmt, catalog=common.CATALOG, schema=SCHEMA)

    print("\n  UDFs created (or already existed).")
    