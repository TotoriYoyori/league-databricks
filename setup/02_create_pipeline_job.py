from pathlib import Path
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.pipelines import PipelineLibrary, PathPattern
from databricks.sdk.service.jobs import Job, Task, PipelineTask, TaskDependency

w = WorkspaceClient()

# --------------- 01. Constants ---------------
CATALOG = "league_records"
SCHEMA_LAYERS = ['bronze', 'silver', 'gold']
JOB_NAME = 'league_csv_etl'

# --------------- 02. Steps ---------------
def to_workspace_path(fs_path: Path) -> str:
    """Converts a /Workspace/... filesystem path to the workspace-style path
    Databricks pipeline APIs expect.

    Args:
        fs_path: Filesystem path, e.g. /Workspace/Repos/<user>/<repo>/....

    Returns:
        The workspace-style path with the /Workspace prefix stripped, e.g.
        /Repos/<user>/<repo>/.... If fs_path doesn't start with /Workspace,
        it is returned unchanged.
    """
    s = str(fs_path)
    if s.startswith("/Workspace"):
        return s[len("/Workspace"):]
    return s


def get_or_create_pipeline(name: str, source_glob: str, layer: str) -> str | None:
    """Get existing pipeline ID by name, or create it if it doesn't exist."""
    pipelines = w.pipelines.list_pipelines(filter=f"name LIKE '{name}'")
    for pipeline in pipelines:
        if pipeline.name == name:
            print(f"Found existing pipeline: {name} ({pipeline.pipeline_id})")
            return pipeline.pipeline_id

    print(f"Creating new pipeline: {name}")
    new_pipeline = w.pipelines.create(
        name=name,
        storage=f"/pipelines/{name}",
        continuous=False,
        catalog=CATALOG,
        schema=layer,
        libraries=[PipelineLibrary(glob=PathPattern(include=source_glob))],
        configuration={"catalog": CATALOG, "schema": layer},
    )
    print(f"Created pipeline: {name} ({new_pipeline.pipeline_id})")
    return new_pipeline.pipeline_id


def create_medallion_job_if_not_exists(
    job_name: str,
    bronze_id: str,
    silver_id: str,
    gold_id: str,
) -> Job:
    """Creates the job that chains the bronze, silver, and gold pipelines
    together in order (bronze -> silver -> gold), unless a job with the
    same name already exists.

    Args:
        bronze_id: Pipeline ID for the bronze layer pipeline.
        silver_id: Pipeline ID for the silver layer pipeline. Runs only
            after the bronze pipeline succeeds.
        gold_id: Pipeline ID for the gold layer pipeline. Runs only after
            the silver pipeline succeeds.
        job_name: Name to give the job. Defaults to "league_csv_etl".

    Returns:
        The existing Job object if one with the same name already exists,
        otherwise the newly created Job object.
    """
    existing_jobs = list(w.jobs.list(name=job_name))
    if existing_jobs:
        existing_job = existing_jobs[0]
        print(f"Found existing job: {job_name} ({existing_job.job_id}), skipping creation.")
        return existing_job

    print("---------- Creating job ----------")
    job = w.jobs.create(
        name=job_name,
        tasks=[
            Task(
                task_key="run_bronze_pipeline",
                pipeline_task=PipelineTask(pipeline_id=bronze_id),
            ),
            Task(
                task_key="run_silver_pipeline",
                depends_on=[TaskDependency(task_key="run_bronze_pipeline")],
                pipeline_task=PipelineTask(pipeline_id=silver_id),
            ),
            Task(
                task_key="run_gold_pipeline",
                depends_on=[TaskDependency(task_key="run_silver_pipeline")],
                pipeline_task=PipelineTask(pipeline_id=gold_id),
            ),
        ],
    )
    print("✅ Job created successfully!")
    print(f"Job ID: {job.job_id}")
    print(f"Job Name: {job.settings.name}")
    return job


# --------------- 03. Main ---------------
if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent
    repo_root_ws_path = to_workspace_path(repo_root)
    model_paths = {
        layer: f"{repo_root_ws_path}/models/{layer}/transformations/**"
        for layer in SCHEMA_LAYERS
    }

    print("---------- Resolved model source globs ----------")
    for name, path in model_paths.items():
        print(f"  {name}: {path}")

    print("---------- Creating or finding pipelines ----------")
    pipeline_ids = {
        f"league_{layer}": get_or_create_pipeline(
            name=f"league_{layer}",
            source_glob=model_paths[layer],
            layer=layer
        )
        for layer in SCHEMA_LAYERS
    }

    job = create_medallion_job_if_not_exists(
        job_name=JOB_NAME,
        **{
            f"{layer}_id": pipeline_ids[f"league_{layer}"]
            for layer in SCHEMA_LAYERS
        }
    )
