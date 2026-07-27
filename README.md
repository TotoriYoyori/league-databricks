# League of Legends Data Pipeline 

**Simple production-grade oneshot LoL analytics pipeline built on Databricks.**

From raw match data to actionable insights: fully automated, reproducible, and portable across workspaces. Featuring a **Bronze → Silver → Gold** medallion architecture.

* 📥 **Automated data ingestion** from GitHub releases.
* 🔄 **Sequential pipeline orchestration** with dependency management  
* 🏗️ **Infrastructure as Code** — one script to rule them all
* 🚀 **Zero hardcoded paths or IDs** — clone and run anywhere

---

## 📂 Project Structure

```
league-databricks/
│
├── setup/                                    # Setup & orchestration scripts
│   ├── 00_catalog_schema.sql                 # Unity Catalog initialization (SQL)
│   ├── 01_download_files_to_volume.py        # Data ingestion from GitHub (Python)
│   ├── 02_create_pipeline_job.py             # Pipeline & job creation (Python)
│   └── _teardown.sql                         # Cleanup script (SQL)
│
├── models/                                   # Data transformation layers
│   ├── bronze/
│   │   └── transformations/                  # Raw data ingestion (Python/SQL)
│   ├── silver/
│   │   └── transformations/                  # Cleaned & conformed data (Python/SQL)
│   └── gold/
│       └── transformations/                  # Analytics-ready aggregates (Python/SQL)
│
└── README.md                                 # You are here
```

---

## 🚀 Quick Start

**Clone this repo to your Databricks workspace**, then run:

```bash
# 1. Setup catalog & schema
python setup/00_catalog_schema.sql

# 2. Download source data  
python setup/01_download_files_to_volume.py

# 3. Create pipelines & job
python setup/02_create_pipeline_job.py
```

**That's it.** Your end-to-end pipeline is live. 🎉

---

## 🎯 Design Principles

* **Portable** — No hardcoded workspace paths or pipeline IDs
* **Declarative** — Infrastructure defined in code, not UI clicks  
* **Modular** — Each layer (bronze/silver/gold) is independent
* **Production-ready** — Triggered pipelines with full dependency management

---

## 📊 Data Sources

Match data sourced from Kaggle League of Legends datasets:
* Champions reference
* Items reference  
* Match summaries
* Player statistics
* Time-series intervals

---

**Built with** ⚡ Databricks | 🐍 Python | 📊 Spark SQL | 🏆 Unity Catalog
