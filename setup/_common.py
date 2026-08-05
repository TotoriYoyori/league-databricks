from databricks.sdk import WorkspaceClient

w = WorkspaceClient()

# --------------- 01. Constants ---------------
PREFERRED_WAREHOUSE_NAME = "Serverless Starter Warehouse"
CATALOG = "league_records"
BRONZE = "bronze"
SILVER = "silver"
GOLD = "gold"
SCHEMA_LAYERS = [BRONZE, SILVER, GOLD]
JOB_NAME = "league_csv_etl"


# --------------- 02. Helpers ---------------
def get_warehouse_id(preferred_name: str = PREFERRED_WAREHOUSE_NAME) -> tuple[str, str]:
    """Finds a SQL warehouse by name. Falls back to the first available
    warehouse in the workspace if the preferred one isn't found.

    Args:
        preferred_name: The name of the preferred SQL warehouse. Defaults
            to PREFERRED_WAREHOUSE_NAME.

    Returns:
        A tuple of (warehouse_id, warehouse_name).

    Raises:
        RuntimeError: If no SQL warehouses exist in the workspace.
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
        f"Warehouse '{preferred_name}' not found! "
        f"falling back to first available warehouse: '{fallback.name}'."
    )
    return fallback.id, fallback.name


def ensure_warehouse_running(warehouse_id: str, warehouse_name: str) -> None:
    """Wakes the warehouse if it's stopped, and blocks until it's usable."""
    info = w.warehouses.get(id=warehouse_id)
    state = getattr(info.state, "value", info.state)
    if state == "RUNNING":
        return
    
    print(f"Warehouse '{warehouse_name}' is {state}, starting it...")
    w.warehouses.start_and_wait(id=warehouse_id)
    print(f"Warehouse '{warehouse_name}' is now running.")


def resolve_running_warehouse(preferred_name: str = PREFERRED_WAREHOUSE_NAME) -> str:
    """Convenience wrapper: finds a warehouse and ensures it's running.

    Args:
        preferred_name: The name of the preferred SQL warehouse.

    Returns:
        The warehouse_id, guaranteed to be in a RUNNING state.
    """
    warehouse_id, warehouse_name = get_warehouse_id(preferred_name)
    ensure_warehouse_running(warehouse_id, warehouse_name)
    return warehouse_id


def run_statement(
    warehouse_id: str,
    statement: str,
    catalog: str | None = None,
    schema: str | None = None,
) -> None:
    """Runs a single SQL statement against the given warehouse.

    Args:
        warehouse_id: ID of the warehouse to run the statement on.
        statement: The SQL statement to execute.
        catalog: Optional catalog context for the statement.
        schema: Optional schema context for the statement.

    Raises:
        RuntimeError: If the statement fails.
    """
    kwargs = {"warehouse_id": warehouse_id, "statement": statement}
    if catalog is not None:
        kwargs["catalog"] = catalog
    if schema is not None:
        kwargs["schema"] = schema

    resp = w.statement_execution.execute_statement(**kwargs)
    if resp.status is not None and resp.status.state is not None:
        state = getattr(resp.status.state, "value", resp.status.state)
        if state == "FAILED":
            error = resp.status.error
            raise RuntimeError(f"Statement failed: {error}\n---\n{statement}")
        
        first_line = statement.strip().splitlines()[0]
        print(f"  [{state}] {first_line}...")
