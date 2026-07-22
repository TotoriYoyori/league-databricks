# Databricks notebook source
# /// script
# [tool.databricks.environment]
# environment_version = "5"
# ///
# MAGIC %sql
# MAGIC USE CATALOG league_records;
# MAGIC
# MAGIC USE SCHEMA silver;

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT *
# MAGIC FROM READ_FILES(
# MAGIC     '/Volumes/league_records/bronze/kaggle_csv/champions/*.csv.gz',
# MAGIC     FORMAT => 'csv',
# MAGIC     INFERSCHEMA => true
# MAGIC )
# MAGIC ;

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT item_category,
# MAGIC     COUNT(*) AS item_n_in_category
# MAGIC FROM items_ref
# MAGIC GROUP BY item_category
# MAGIC ORDER BY item_n_in_category DESC
# MAGIC ;

# COMMAND ----------

