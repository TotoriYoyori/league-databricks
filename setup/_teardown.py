"""
Full teardown for the whole ETL pipeline, including all catalog tables, schemas,
volumes, stored data, as well as the jobs and pipelines that were created.

DO NOT RUN THIS UNLESS YOU TRULY WANT TO TAKE EVERYTHING DOWN!
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _common as c

# --------------- 01. Constants ---------------
DROP_CATALOG_STATEMENT = f"DROP CATALOG IF EXISTS {c.CATALOG} CASCADE"


# --------------- 02. Pipeline / job teardown ---------------
def find_job_id(job_name: str) -> int | None:
    existing_jobs = list(c.w.jobs.list(name=job_name))
    if not existing_jobs:
        return None

    return existing_jobs[0].job_id


def find_pipeline_id(name: str) -> str | None:
    pipelines = c.w.pipelines.list_pipelines(filter=f"name LIKE '{name}'")
    for pipeline in pipelines:
        if pipeline.name == name:
            return pipeline.pipeline_id

    return None


def delete_job(job_id: int, job_name: str) -> None:
    """Deletes a job by ID."""
    c.w.jobs.delete(job_id=job_id)
    print(f"Deleted job: {job_name} ({job_id})")


def delete_pipeline(pipeline_id: str, name: str) -> None:
    """Deletes a pipeline by ID."""
    c.w.pipelines.delete(pipeline_id=pipeline_id)
    print(f"Deleted pipeline: {name} ({pipeline_id})")


# --------------- 03. Main ---------------
if __name__ == "__main__":
    print("---------- Resolving SQL warehouse ----------")
    warehouse_id = c.resolve_running_warehouse()

    print("\n---------- Dropping catalog (and all data within it) ----------")
    c.run_statement(warehouse_id, DROP_CATALOG_STATEMENT)
    print(f"  Catalog '{c.CATALOG}' dropped (or did not exist).")

    print("\n---------- Finding job and pipelines ----------")
    job_id = find_job_id(c.JOB_NAME)
    pipeline_ids = {
        layer: find_pipeline_id(f"league_{layer}")
        for layer in c.SCHEMA_LAYERS
    }

    print(f"  Job '{c.JOB_NAME}': {job_id or '(not found)'}")
    for layer, pid in pipeline_ids.items():
        print(f"  Pipeline 'league_{layer}': {pid or '(not found)'}")

    print("\n---------- Deleting job ----------")
    if job_id is not None:
        delete_job(job_id, c.JOB_NAME)
    else:
        print(f"Job '{c.JOB_NAME}' not found, skipping.")

    print("\n---------- Deleting pipelines ----------")
    for layer, pid in pipeline_ids.items():
        if pid is not None:
            delete_pipeline(pid, f"league_{layer}")
        else:
            print(f"Pipeline 'league_{layer}' not found, skipping.")

    print("\n  Teardown complete.")
