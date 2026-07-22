-------------------------------------------------------------------------------------------
-- ⚠ WARNING — DESTRUCTIVE TEARDOWN SCRIPT ⚠
--
-- This script permanently drops all silver streaming tables and their underlying
-- Delta data files. This is NOT a reversible operation. All change histories and 
-- current-state data will be lost.
-----------------------------------------------------------------------------------------
DROP TABLE IF EXISTS league_records.silver.items_ref;
DROP TABLE IF EXISTS league_records.silver.champions_ref;