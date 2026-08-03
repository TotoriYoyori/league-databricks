# League of Legends Data Pipeline 

**Simple oneshot LoL analytics pipeline built on Databricks.**

1. This project was built on a set of readily available .csv from Kaggle --> [*source*](https://www.kaggle.com/datasets/nathansmallcalder/league-of-legends-match-interval-snapshots-2026/data). The dataset itself was in turn sourced from [*Raw Community Dragon*](https://raw.communitydragon.org/). 

2. This project only ingested all the raw .csv one time and run them through a medallion data pipeline. For a version of this pipeline, deployed on Snowflake, with simulated daily ingestion and incremental loading, see [*here*](https://github.com/TotoriYoyori/league-snowflake).

---

## 📂 Project Structure

```
league-databricks/
├── setup/            # Catalog init, data ingestion, pipeline/job creation
├── models/
│   ├── bronze/       # Raw data ingestion
│   ├── silver/       # Cleaned & conformed data (+ shared utilities)
│   └── gold/         # Analytics-ready aggregates
│       # each layer contains transformations/, which is the pipeline source code runnable by Databricks. 
│       
├── analytics/        # Ad-hoc notebooks for model iterating
├── dashboards/       # Lakeview dashboards for fast visualizations
├── deploy.py         # One-line deployment script
└── README.md
```
---
## ✅ Prerequisites to Deploy

* A Databricks workspace with **Unity Catalog enabled** and permission to **create a catalog**.
* A startable **SQL Warehouse** (`deploy.py` looks for "Serverless Starter Warehouse" by default) as well as any **all-purpose cluster** (including Serverless).

> *Info: A new DataBricks free-edition trial account will give you all the above for free!* 
---

## 🚀 How to Deploy

1. Clone this repo into your Databricks workspace.
2. From the **Web Terminal** (attached to Serverless or an all-purpose cluster) **at project root**, run `python deploy.py`, example below:
```bash
Workspace/Users/<your_email>@<domain.com>/league-databricks$ python deploy.py
```

That's it. 

---

**Built with** --> Databricks | Python | SQL | Unity Catalog
