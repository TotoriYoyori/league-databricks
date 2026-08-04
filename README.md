<img width="1500" height="500" alt="gw4h3begfrc81" src="https://github.com/user-attachments/assets/ba1952a1-8409-4ed0-83aa-587b429b3fe4" />

# League of Legends ETL Data Pipeline 

**Simple oneshot LoL analytics pipeline built on Databricks.**

1. This project was built on a set of readily available .csv from Kaggle --> [*source*](https://www.kaggle.com/datasets/nathansmallcalder/league-of-legends-match-interval-snapshots-2026/data). The dataset itself was in turn sourced from [*Raw Community Dragon*](https://raw.communitydragon.org/). 

2. This project only ingested all the raw .csv one time and run them through a medallion data pipeline. For a version of this pipeline, deployed on Snowflake, with simulated daily ingestion and incremental loading, see [*here*](https://github.com/TotoriYoyori/league-snowflake).

---

## Project Structure

```
league-databricks/
├── setup/            # Catalog init, data ingestion, pipeline/job creation
├── models/           # each layer shares the same structure, as shown here under bronze/
│   ├── bronze/       # Raw data ingestion
│   │   ├── transformations/       # Pipeline source code for table DDL run by Databricks.
│   │   ├── exploration/           # adhoc query for testings, dry runs and exploration
│   ├── silver/       # Cleaned & conformed data (+ shared utilities)
│   └── gold/         # Analytics-ready aggregates
│       
├── analytics/                   # Data science workflows example
│   ├── 01_sample_eda            # EDA analytics with pandas, numpy, matplotlib, seaborn
│   ├── 02_sample_modelling      # Fitting a model using sklearn
├── dashboards/       # includes: data browser, data aggregation, and pipeline monitoring
├── deploy.py         # One-line deployment script
└── README.md
```
---
## Prerequisites to Deploy

* A Databricks workspace with **Unity Catalog enabled** and permission to **create a catalog**.
* A startable **SQL Warehouse** (`deploy.py` looks for "Serverless Starter Warehouse" by default) as well as any **all-purpose cluster** (including Serverless).

<img width="513" height="241" alt="prereq" src="https://github.com/user-attachments/assets/80424aae-d150-43ff-8b56-392b54acd9fb" />

> *Info: A new DataBricks free-edition trial account will give you all the above for free!*

---

## How to Deploy

1. Clone this repo into your Databricks workspace by **creating a new 'Git Folder'** in the top right and enter this repo's clone link. Keep the name of the folder as default.
   
<img width="269" height="584" alt="setup_01_gitclone" src="https://github.com/user-attachments/assets/0d2fad5f-83dd-476c-ad76-93cfdd56780c" />
<img width="875" height="352" alt="setup_02_entergit" src="https://github.com/user-attachments/assets/b7371c2d-1d91-45e6-b5dc-de302779ff93" />
   
2. From the **Web Terminal** (attached to Serverless or an all-purpose cluster) **at project root**, run `python deploy.py`, example below:
```bash
Workspace/Users/<your_email>@<domain.com>/league-databricks$ python deploy.py
```
<img width="632" height="224" alt="setup_06_success" src="https://github.com/user-attachments/assets/22c3381b-0836-4f5c-8188-400592d3e5b1" />

> *You should see something like the above picture when the deployment is successfully done.*

3. Go to **Jobs & Pipeline** in your sidebar to the left, click on the newly created **league_csv_etl** job, and you will see a button 'Run Now'. Click on it to start the pipeline. On your first cold start, it **might take up to 20 minutes** for the Serverless cluster to start up and finish, but subsequent warm runs usually take <= 5 minutes.
   
<img width="1118" height="423" alt="setup_08_run_now" src="https://github.com/user-attachments/assets/51e4061f-6682-4a93-8403-353ac0bb2bee" />

That's it! 

---

**Built with** --> Databricks | Python | SQL | Unity Catalog | 
**Python Library Used** --> Pandas | NumPy | Matplotlib | Seaborn | Sklearn | Statsmodels | And others...
