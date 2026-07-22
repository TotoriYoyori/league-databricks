import os
import requests

# --------------- 01. Constants ---------------
VOLUME_DIR = "/Volumes/league_records/bronze/kaggle_csv"
RELEASE_BASE_URL = "https://github.com/TotoriYoyori/league-databricks/releases/download/source"
FILE_TO_SUBFOLDER = {
    "champions_ref.csv.gz": "champions",
    "intervals.csv.gz": "intervals",
    "items_ref.csv.gz": "items",
    "matches_summary.csv.gz": "matches",
    "players_summary.csv.gz": "players",
}


# --------------- 02. Helpers ---------------
def create_if_not_exists(dir: str) -> None:
    if os.path.isdir(dir):
        print(f"Already exists, skipping: {dir}")
    else:
        os.makedirs(dir)
        print(f"Created folder: {dir}")


def download_file(from_url: str, to_vol_path: str) -> None:
    response = requests.get(from_url)
    response.raise_for_status()
    with open(to_vol_path, "wb") as f:
        f.write(response.content)

    print(f"Downloaded {from_url} -> {to_vol_path}")


# --------------- 03. Main ---------------
if __name__ == "__main__":
    create_if_not_exists(VOLUME_DIR)
    for subfolder in set(FILE_TO_SUBFOLDER.values()):
        create_if_not_exists(os.path.join(VOLUME_DIR, subfolder))

    for filename, subfolder in FILE_TO_SUBFOLDER.items():
        print("-" * 50)

        url = f"{RELEASE_BASE_URL}/{filename}"
        dest_path = os.path.join(VOLUME_DIR, subfolder, filename)
        download_file(url, dest_path)
