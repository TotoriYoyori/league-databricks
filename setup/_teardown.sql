--------------------------------------------------
-- DO NOT RUN UNLESS YOU KNOW WHAT YOU ARE DOING. 
-- This script will tear down the entire league_records catalog, thereby not only wiping all
-- artifacts within (schemas, tables, views, functions, etc.) but also all data. 
--------------------------------------------------
DROP CATALOG IF EXISTS league_records CASCADE;
