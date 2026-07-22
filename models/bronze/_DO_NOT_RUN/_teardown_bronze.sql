-------------------------------------------------------------------------------------------
-- ⚠ WARNING — DESTRUCTIVE TEARDOWN SCRIPT ⚠
--
-- This script permanently drops all 5 bronze streaming tables and their underlying
-- Delta data files. This is NOT a reversible operation — all ingested data, table
-- history, and streaming checkpoints will be lost.
-------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS league_records.bronze.items_ref;
DROP TABLE IF EXISTS league_records.bronze.champions_ref;
DROP TABLE IF EXISTS league_records.bronze.matches;
DROP TABLE IF EXISTS league_records.bronze.players;
DROP TABLE IF EXISTS league_records.bronze.intervals;
