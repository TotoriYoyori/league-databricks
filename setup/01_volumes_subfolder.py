import os

# --------------- 01. Constants ---------------
VOLUME_DIR = "/Volumes/league_records/bronze/kaggle_csv"
SUBFOLDERS = ["matches", "players", "intervals", "items", "champions"]


# --------------- 02. Helpers ---------------
def create_if_not_exists(path: str) -> None:
    """No-op if the folder already exists (from previous step 00_catalog_schema.sql), otherwise creates it."""
    if os.path.isdir(path):
        pass
    else:
        os.makedirs(path)


# --------------- 03. Main ---------------
if __name__ == "__main__":
    create_if_not_exists(VOLUME_DIR)
    for subfolder in SUBFOLDERS:
        subfolder_path = os.path.join(VOLUME_DIR, subfolder)
        create_if_not_exists(subfolder_path)
        