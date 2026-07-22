# Databricks notebook source
# MAGIC %sql
# MAGIC SELECT
# MAGIC     item_id                                    AS ITEM_ID,
# MAGIC     item_name                                  AS ITEM_NAME,
# MAGIC     item_category                              AS ITEM_CATEGORY,
# MAGIC     CAST(current_timestamp() AS TIMESTAMP_NTZ) AS LDTS,
# MAGIC     _metadata.file_name                        AS FILE_NAME,
# MAGIC     'League Static Data'                       AS RSRC
# MAGIC FROM READ_FILES(
# MAGIC     '/Volumes/league_records/bronze/kaggle_csv/items/*.csv.gz',
# MAGIC     format => "csv",
# MAGIC     header => true,
# MAGIC     schema => "
# MAGIC         item_id STRING, 
# MAGIC         item_name STRING, 
# MAGIC         item_category STRING
# MAGIC     "
# MAGIC );

# COMMAND ----------

# MAGIC %sql
# MAGIC USE CATALOG league_records;
# MAGIC
# MAGIC USE SCHEMA bronze;

# COMMAND ----------

display(spark.sql(
"""
SELECT COUNT(*) 
FROM items_ref
;
"""
))

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT *
# MAGIC FROM READ_FILES(
# MAGIC     '/Volumes/league_records/bronze/kaggle_csv/matches/*.csv.gz',
# MAGIC     FORMAT => "csv",
# MAGIC     HEADER => true,
# MAGIC     INFERSCHEMA => true
# MAGIC )
# MAGIC ;

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT 
# MAGIC     -- Source
# MAGIC     id,
# MAGIC     match_id,
# MAGIC     participant_id,
# MAGIC     team_id,
# MAGIC     champion,
# MAGIC     role,
# MAGIC     individual_position,
# MAGIC     -- Metadata
# MAGIC     CURRENT_TIMESTAMP() AS ldts,
# MAGIC     _metadata.file_name AS file_name,
# MAGIC     'Kaggle' AS rsrc
# MAGIC FROM READ_FILES(
# MAGIC     '/Volumes/league_records/bronze/kaggle_csv/players/*.csv.gz',
# MAGIC     FORMAT => 'csv',
# MAGIC     HEADER => true,
# MAGIC     DELIMITER => ',',
# MAGIC     QUOTE => '"',
# MAGIC     IGNORELEADINGWHITESPACE => true,
# MAGIC     IGNORETRAILINGWHITESPACE => true,
# MAGIC     SCHEMA => '
# MAGIC         id STRING,
# MAGIC         match_id STRING,
# MAGIC         participant_id STRING,
# MAGIC         team_id STRING,
# MAGIC         champion STRING,
# MAGIC         role STRING,
# MAGIC         individual_position STRING
# MAGIC     '
# MAGIC )
# MAGIC ;

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT * 
# MAGIC FROM READ_FILES(
# MAGIC     '/Volumes/league_records/bronze/kaggle_csv/intervals/*.csv.gz',
# MAGIC     FORMAT => 'csv',
# MAGIC     HEADER => true,
# MAGIC     DELIMITER => ',',
# MAGIC     QUOTE => '"',
# MAGIC     IGNORELEADINGWHITESPACE => true,
# MAGIC     IGNORETRAILINGWHITESPACE => true,
# MAGIC     INFERSCHEMA => true
# MAGIC )
# MAGIC ORDER BY RANDOM()
# MAGIC LIMIT 10
# MAGIC ;

# COMMAND ----------

