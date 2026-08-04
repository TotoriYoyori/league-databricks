from pathlib import Path
import requests

# --------------- 01. Constants ---------------
VOLUME_DIR = Path("/Volumes/league_records/bronze/kaggle_csv")
RELEASE_BASE_URL = "https://github.com/TotoriYoyori/league-databricks/releases/download/source"
FILE_TO_SUBFOLDER = {
    "champions_ref.csv.gz": "champions",
    "intervals.csv.gz": "intervals",
    "items_ref.csv.gz": "items",
    "matches_summary.csv.gz": "matches",
    "players_summary.csv.gz": "players",
}
MAX_RETRIES = 3


# --------------- 02. Helpers ---------------
def create_if_not_exists(directory: Path) -> None:
    """Creates a directory if it doesn't already exist.

    Args:
        directory: Path to the directory to create. Parent directories
            are created as needed.
    """
    if directory.is_dir():
        print(f"Already exists, skipping: {directory}")
    else:
        directory.mkdir(parents=True)
        print(f"Created folder: {directory}")


def download_file_if_not_exists(
    from_url: str, 
    to_vol_path: Path
) -> None:
    """Downloads a file to the given path, unless a non-empty file already exists there.

    A 0-byte file at the destination is treated as an incomplete download
    from a previous interrupted run, and is retried rather than skipped.
    Retries up to MAX_RETRIES times on request failures before giving up.

    Args:
        from_url: URL to download the file from.
        to_vol_path: Destination path to write the downloaded file to.

    Raises:
        RuntimeError: If the download fails after MAX_RETRIES attempts.
    """
    if to_vol_path.exists() and to_vol_path.stat().st_size > 0:
        print(f"Already exists, skipping: {to_vol_path} ({to_vol_path.stat().st_size} bytes)")
        return

    last_error = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = requests.get(from_url)
            response.raise_for_status()
            to_vol_path.write_bytes(response.content)
            print(f"Downloaded {from_url} -> {to_vol_path} ({to_vol_path.stat().st_size} bytes)")
            return
        except requests.exceptions.RequestException as e:
            last_error = e
            print(f"  Attempt {attempt}/{MAX_RETRIES} failed for {from_url}: {e}")

    raise RuntimeError(
        f"Failed to download {from_url} after {MAX_RETRIES} attempts"
    ) from last_error


# --------------- 03. Main ---------------
if __name__ == "__main__":
    create_if_not_exists(VOLUME_DIR)
    for subfolder in set(FILE_TO_SUBFOLDER.values()):
        create_if_not_exists(VOLUME_DIR / subfolder)

    for filename, subfolder in FILE_TO_SUBFOLDER.items():
        print("-" * 50)

        url = f"{RELEASE_BASE_URL}/{filename}"
        dest_path = VOLUME_DIR / subfolder / filename
        download_file_if_not_exists(url, dest_path)

    print("\n  Done.")