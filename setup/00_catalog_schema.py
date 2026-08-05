import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _common as c

# --------------- 01. Constants ---------------
STATEMENTS = [
    # ----- Create catalog
    f"""
    CREATE CATALOG IF NOT EXISTS {c.CATALOG}
    COMMENT 'League of Legends match analytics, sourced from Kaggle.'
    """,
    # ----- Create bronze artifacts
    f"""
    CREATE SCHEMA IF NOT EXISTS {c.CATALOG}.{c.BRONZE}
    COMMENT 'Bronze layer, ingested as is from source with metadata.'
    """,
    f"""
    CREATE VOLUME IF NOT EXISTS {c.CATALOG}.{c.BRONZE}.kaggle_csv
    COMMENT 'Volumes to store raw .csv files from source.'
    """,
    # ----- Create silver artifacts
    f"""
    CREATE SCHEMA IF NOT EXISTS {c.CATALOG}.{c.SILVER}
    COMMENT 'Silver layer, transformed and deduped from bronze.'
    """,
    # ----- Create gold artifacts
    f"""
    CREATE SCHEMA IF NOT EXISTS {c.CATALOG}.{c.GOLD}
    COMMENT 'Gold layer, aggregated and ready for end users consumption.'
    """,
]


# --------------- 02. Main ---------------
if __name__ == "__main__":
    print("---------- Resolving SQL warehouse ----------")
    warehouse_id = c.resolve_running_warehouse()

    print("---------- Creating catalog / schemas / volume ----------")
    for stmt in STATEMENTS:
        c.run_statement(warehouse_id, stmt)

    print("  Catalog, schemas, and volume created (or already existed).")
    