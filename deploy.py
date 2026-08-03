"""
Command help:
    python deploy.py            # run all steps in sequence
    python deploy.py --only 01  # run just one step, by its number prefix
    python deploy.py --from 01  # run from a given step to the end
    python deploy.py --list     # show available step
"""

import argparse
import subprocess
import sys
from pathlib import Path


# --------------- 01. Constants ---------------
REPO_ROOT = Path(__file__).resolve().parent
SETUP_DIR = REPO_ROOT / "setup"
STEPS = [
    ("00", SETUP_DIR / "00_catalog_schema.py"),
    ("01", SETUP_DIR / "01_download_files_to_volume.py"),
    ("02", SETUP_DIR / "02_create_pipeline_job.py"),
    ("03", SETUP_DIR / "03_create_udf.py"),
]


# --------------- 02. Helper ---------------
def run_step(number: str, path: Path) -> None:
    """Runs a single setup step as a subprocess, streaming its output live.

    Args:
        number: The step's identifying prefix (e.g. "00").
        path: Path to the step's script file.

    Raises:
        FileNotFoundError: If the script file doesn't exist.
        subprocess.CalledProcessError: If the step exits with a nonzero
            status, propagated so the whole sequence halts on failure.
    """
    if not path.exists():
        raise FileNotFoundError(f"Step {number} not found at {path}")

    print(f"\n{'=' * 60}")
    print(f"Running step {number}: {path.name}")
    print(f"{'=' * 60}\n")

    subprocess.run([sys.executable, str(path)], check=True)

    print(f"\n✅ Step {number} ({path.name}) completed.\n")


# --------------- 03. Main ---------------
def main() -> None:
    parser = argparse.ArgumentParser(description="Run league-databricks setup steps.")
    parser.add_argument(
        "--only", metavar="STEP",
        help="Run only this step number (e.g. --only 01)",
    )
    parser.add_argument(
        "--from", dest="from_step", metavar="STEP",
        help="Run from this step number through the end (e.g. --from 01)",
    )
    parser.add_argument(
        "--list", action="store_true",
        help="List available steps and exit",
    )
    args = parser.parse_args()

    if args.list:
        print("Available steps:")
        for number, path in STEPS:
            print(f"  {number}: {path.name}")
        return

    if args.only:
        matches = [(n, p) for n, p in STEPS if n == args.only]
        if not matches:
            available = ", ".join(n for n, _ in STEPS)
            raise SystemExit(f"Unknown step '{args.only}'. Available: {available}")
        run_step(*matches[0])
        return

    steps_to_run = STEPS
    if args.from_step:
        start_index = next(
            (i for i, (n, _) in enumerate(STEPS) if n == args.from_step), None
        )
        if start_index is None:
            available = ", ".join(n for n, _ in STEPS)
            raise SystemExit(f"Unknown step '{args.from_step}'. Available: {available}")
        steps_to_run = STEPS[start_index:]

    for number, path in steps_to_run:
        run_step(number, path)

    print("\n🎉 All steps completed successfully!")


if __name__ == "__main__":
    main()
    