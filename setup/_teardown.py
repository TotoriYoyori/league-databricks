"""
Full teardown for the whole ETL pipeline, including all catalog tables, schemas,
volumes, stored data, as well as the jobs and pipelines that were created.

DO NOT RUN THIS UNLESS YOU TRULY WANT TO TAKE EVERYTHING DOWN!
"""

from databricks.sdk import WorkspaceClient

w = WorkspaceClient()

# --------------- 01. Constants ---------------
PREFERRED_WAREHOUSE_NAME = "Serverless Starter Warehouse"
CATALOG = "league_records"
SCHEMA_LAYERS = ['bronze', 'silver', 'gold']
JOB_NAME = 'league_csv_etl'

DROP_CATALOG_STATEMENT = f"DROP CATALOG IF EXISTS {CATALOG} CASCADE"


# --------------- 02. Warehouse / catalog teardown ---------------
def get_warehouse_id(preferred_name: str) -> tuple[str, str]:
    """Finds a SQL warehouse by name. Falls back to the first available
    warehouse in the workspace if the preferred one isn't found.
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
    """Wakes the warehouse if it's stopped, and blocks until it's usable."""
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


# --------------- 03. Pipeline / job teardown ---------------
def find_job_id(job_name: str) -> int | None:
    existing_jobs = list(w.jobs.list(name=job_name))
    if not existing_jobs:
        return None
    
    return existing_jobs[0].job_id


def find_pipeline_id(name: str) -> str | None:
    pipelines = w.pipelines.list_pipelines(filter=f"name LIKE '{name}'")
    for pipeline in pipelines:
        if pipeline.name == name:
            return pipeline.pipeline_id
        
    return None


def delete_job(job_id: int, job_name: str) -> None:
    """Deletes a job by ID."""
    w.jobs.delete(job_id=job_id)
    print(f"Deleted job: {job_name} ({job_id})")


def delete_pipeline(pipeline_id: str, name: str) -> None:
    """Deletes a pipeline by ID."""
    w.pipelines.delete(pipeline_id=pipeline_id)
    print(f"Deleted pipeline: {name} ({pipeline_id})")


# --------------- 04. Main ---------------
if __name__ == "__main__":
    print("---------- Resolving SQL warehouse ----------")
    warehouse_id, warehouse_name = get_warehouse_id(PREFERRED_WAREHOUSE_NAME)
    ensure_warehouse_running(warehouse_id, warehouse_name)

    print("\n---------- Dropping catalog (and all data within it) ----------")
    run_statement(warehouse_id, DROP_CATALOG_STATEMENT)
    print(f"  Catalog '{CATALOG}' dropped (or did not exist).")

    print("\n---------- Finding job and pipelines ----------")
    job_id = find_job_id(JOB_NAME)
    pipeline_ids = {
        layer: find_pipeline_id(f"league_{layer}")
        for layer in SCHEMA_LAYERS
    }

    print(f"  Job '{JOB_NAME}': {job_id or '(not found)'}")
    for layer, pid in pipeline_ids.items():
        print(f"  Pipeline 'league_{layer}': {pid or '(not found)'}")

    print("\n---------- Deleting job ----------")
    if job_id is not None:
        delete_job(job_id, JOB_NAME)
    else:
        print(f"Job '{JOB_NAME}' not found, skipping.")

    print("\n---------- Deleting pipelines ----------")
    for layer, pid in pipeline_ids.items():
        if pid is not None:
            delete_pipeline(pid, f"league_{layer}")
        else:
            print(f"Pipeline 'league_{layer}' not found, skipping.")

    print("\n  Teardown complete.")
    