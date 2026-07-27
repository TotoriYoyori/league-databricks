from pathlib import Path
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.pipelines import PipelineLibrary, PathPattern
from databricks.sdk.service.jobs import Task, PipelineTask, TaskDependency

w = WorkspaceClient()

# --------------- 01. Constants ---------------
CATALOG = "league_records"


# --------------- 02. Steps ---------------
def to_workspace_path(fs_path: Path) -> str:
    """Convert a /Workspace/... filesystem path to the workspace-style path
    Databricks pipeline APIs expect (e.g. /Repos/<user>/<repo>/...)."""
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


# --------------- 03. Main ---------------
if __name__ == "__main__":
    repo_root = Path(__file__).resolve().parent.parent 
    repo_root_ws_path = to_workspace_path(repo_root)

    model_paths = {
        "bronze": f"{repo_root_ws_path}/models/bronze/transformations/**",
        "silver": f"{repo_root_ws_path}/models/silver/transformations/**",
        "gold": f"{repo_root_ws_path}/models/gold/transformations/**",
    }

    print("---------- Resolved model source globs ----------")
    for name, path in model_paths.items():
        print(f"  {name}: {path}")

    print("---------- Creating or finding pipelines ----------")
    PIPELINE_IDS = {
        "league_bronze": get_or_create_pipeline(
            name="league_bronze", 
            source_glob=model_paths["bronze"], 
            layer="bronze"
        ),
        "league_silver": get_or_create_pipeline("league_silver", model_paths["silver"], "silver"),
        "league_gold": get_or_create_pipeline("league_gold", model_paths["gold"], "gold"),
    }

    print("---------- Creating job ----------")
    job = w.jobs.create(
        name="League Data Pipeline - Bronze to Gold",
        tasks=[
            Task(
                task_key="run_bronze_pipeline",
                pipeline_task=PipelineTask(pipeline_id=PIPELINE_IDS["league_bronze"]),
            ),
            Task(
                task_key="run_silver_pipeline",
                depends_on=[TaskDependency(task_key="run_bronze_pipeline")],
                pipeline_task=PipelineTask(pipeline_id=PIPELINE_IDS["league_silver"]),
            ),
            Task(
                task_key="run_gold_pipeline",
                depends_on=[TaskDependency(task_key="run_silver_pipeline")],
                pipeline_task=PipelineTask(pipeline_id=PIPELINE_IDS["league_gold"]),
            ),
        ],
    )

    print("✅ Job created successfully!")
    print(f"Job ID: {job.job_id}")
    print(f"Job Name: {job.settings.name}")