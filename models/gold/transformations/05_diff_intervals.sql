-------------------------------------------------------------------------------------------
-- DESIGN NOTES:
--     Grain is (match_id, participant_pos_id, minute) -- one row per player, per 5 minutes.
-------------------------------------------------------------------------------------------
CREATE OR REFRESH MATERIALIZED VIEW diff_intervals (
    -- Key
    match_id STRING NOT NULL,
    participant_pos_id INT NOT NULL COMMENT 'The index position of the player at queue time. 1-5 for BLUE side, 6-10 for RED side.',
    minute INT NOT NULL COMMENT 'Minute mark of this snapshot, in 5-minute intervals.',
    -- Player / lane identity
    team STRING COMMENT 'BLUE or RED.',
    champion_role STRING COMMENT 'Resolved role played, based on in-game signals.',
    champion_name STRING COMMENT 'Champion played.',
    -- Player-minute diffs
    gold_diff INT COMMENT '(This player''s total gold - their direct lane opponent''s), at this minute snapshot.',
    xp_diff INT COMMENT '(This player''s xp - their direct lane opponent''s), at this minute snapshot.',

    CONSTRAINT diff_interval_pkey PRIMARY KEY (match_id, participant_pos_id, minute)
)
CLUSTER BY (match_id, participant_pos_id, minute)
COMMENT '[gold] Silver player interval focused on economy diff state enriched with lane/champion identity only.'
AS
-------------------------------------------------------------------------------------------
-- 01. player_diff_interval_state_cte
--     Join silver player-minute intervals to player identity (team/lane/champion).
-------------------------------------------------------------------------------------------
WITH player_diff_interval_state_cte AS (
    SELECT
        -- Primary key
        s.match_id,
        s.participant_pos_id,
        s.minute,
        -- Player / lane identity
        p.team,
        p.champion_role,
        p.champion_name,
        -- Player-minute diffs
        s.gold_diff,
        s.xp_diff
    FROM league_records.silver.intervals AS s
    JOIN league_records.silver.players AS p
        ON s.match_id = p.match_id
       AND s.participant_pos_id = p.participant_pos_id
)

-------------------------------------------------------------------------------------------
-- Select all above for complete query
-------------------------------------------------------------------------------------------
SELECT
    match_id,
    participant_pos_id,
    minute,
    team,
    champion_role,
    champion_name,
    gold_diff,
    xp_diff
FROM player_diff_interval_state_cte
;