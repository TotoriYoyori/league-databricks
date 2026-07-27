from databricks.sdk import WorkspaceClient

w = WorkspaceClient()

# --------------- 01. Constants ---------------
PREFERRED_WAREHOUSE_NAME = "Serverless Starter Warehouse"
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


# --------------- 02. Helpers ---------------
def get_warehouse_id(preferred_name: str) -> tuple[str | None, str | None]:
    """
    Finds a SQL warehouse by name. Falls back to the first available warehouse
    in the workspace if the preferred one isn't found.

    Args:
        preferred_name (str): The name of the preferred SQL warehouse.

    Returns:
        tuple[str, str]: A tuple containing the warehouse ID and warehouse name.
    """
    all_warehouses = list(w.warehouses.list())
    if not all_warehouses:
        raise RuntimeError(
            "No SQL warehouses found in this workspace. Create one first "
            "(SQL Warehouses > Create warehouse) and re-run this script."
        )

    for wh in all_warehouses:
        if wh.name == preferred_name:
            return wh.id, wh.name

    fallback = all_warehouses[0]
    print(
        f"Warehouse '{preferred_name}' not found — "
        f"falling back to first available warehouse: '{fallback.name}'."
    )
    return fallback.id, fallback.name


def ensure_warehouse_running(warehouse_id: str, warehouse_name: str) -> None:
    """Wake the warehouse if it's stopped, and block until it's usable."""
    info = w.warehouses.get(id=warehouse_id)
    state = getattr(info.state, "value", info.state)
    if state == "RUNNING":
        return
    
    print(f"Warehouse '{warehouse_name}' is {state}, starting it...")
    w.warehouses.start_and_wait(id=warehouse_id)
    print(f"Warehouse '{warehouse_name}' is now running.")


def run_statement(warehouse_id: str, statement: str) -> None:
    resp = w.statement_execution.execute_statement(
        warehouse_id=warehouse_id,
        statement=statement,
    )
    if resp.status is not None and resp.status.state is not None:
        state = getattr(resp.status.state, "value", resp.status.state)
        if state == "FAILED":
            error = resp.status.error
            raise RuntimeError(f"Statement failed: {error}\n---\n{statement}")

        print(f"  [{state}] {statement.strip().splitlines()[0]}...")


# --------------- 03. Main ---------------
if __name__ == "__main__":
    print(f"---------- Resolving SQL warehouse ----------")
    warehouse_id, warehouse_name = get_warehouse_id(PREFERRED_WAREHOUSE_NAME)
    ensure_warehouse_running(warehouse_id, warehouse_name)

    print("---------- Creating catalog / schemas / volume ----------")
    for stmt in STATEMENTS:
        run_statement(warehouse_id, stmt)

    print("✅ Catalog, schemas, and volume created (or already existed).")
    