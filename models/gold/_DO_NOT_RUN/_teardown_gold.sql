-------------------------------------------------------------------------------------------
-- ⚠ WARNING — DESTRUCTIVE TEARDOWN SCRIPT ⚠
--
-- This script permanently drops all gold materialized view and their underlying
-- Delta data files. This is NOT a reversible operation. All change histories and 
-- current-state data will be lost.
-----------------------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS league_records.gold.matchend_stats;
DROP MATERIALIZED VIEW IF EXISTS league_records.gold.champion_overviews;
DROP MATERIALIZED VIEW IF EXISTS league_records.gold.matchend_pivot_teamstats;
DROP MATERIALIZED VIEW IF EXISTS league_records.gold.item_recommendations;
DROP MATERIALIZED VIEW IF EXISTS league_records.gold.diff_intervals;

DROP VIEW IF EXISTS league_records.gold._noref_champion_names;