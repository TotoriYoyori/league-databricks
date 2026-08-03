import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _common as common

# --------------- 01. Constants ---------------
STATEMENTS = [
    # ----- Create catalog
    """
    CREATE CATALOG IF NOT EXISTS league_records
    COMMENT 'League of Legends match analytics, sourced from Kaggle.'
    """,
    # ----- Create bronze artifacts
    """
    CREATE SCHEMA IF NOT EXISTS league_records.bronze
    COMMENT 'Bronze layer, ingested as is from source with metadata.'
    """,
    """
    CREATE VOLUME IF NOT EXISTS league_records.bronze.kaggle_csv
    COMMENT 'Volumes to store raw .csv files from source.'
    """,
    # ----- Create silver artifacts
    """
    CREATE SCHEMA IF NOT EXISTS league_records.silver
    COMMENT 'Silver layer, transformed and deduped from bronze.'
    """,
    # ----- Create gold artifacts
    """
    CREATE SCHEMA IF NOT EXISTS league_records.gold
    COMMENT 'Gold layer, aggregated and ready for end users consumption.'
    """,
]


# --------------- 02. Main ---------------
if __name__ == "__main__":
    print("---------- Resolving SQL warehouse ----------")
    warehouse_id = common.resolve_running_warehouse()

    print("---------- Creating catalog / schemas / volume ----------")
    for stmt in STATEMENTS:
        common.run_statement(warehouse_id, stmt)

    print("✅ Catalog, schemas, and volume created (or already existed).")
    