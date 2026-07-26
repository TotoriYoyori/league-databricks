CREATE OR REFRESH MATERIALIZED VIEW item_recommendations (
    -- Key
    champion_name STRING NOT NULL COMMENT 'Champion this row''s item stats apply to.',
    item_name STRING NOT NULL COMMENT 'Item name.',
    -- Context
    item_category STRING COMMENT 'Item category (Trinket, Consumable, Starter, Basic, Boots, Epic, Legendary, or excluded categories).',
    -- Stats
    player_purchase_rate DOUBLE COMMENT 'Share of all players on this champion who ended their match with this item.',
    win_rate DOUBLE COMMENT 'Win rate for matches where this champion ended with this item.',
    avg_kda DOUBLE COMMENT 'Average (kills + assists) / (deaths + 1) across players on this champion who ended with this item.',
    most_common_first_purchase_minute INT COMMENT 'Most common 5-minute interval mark at which this item first appeared in a player''s inventory, for this champion.',
    -- Recommendations
    top_item_1 STRING COMMENT 'Most commonly co-purchased item.',
    top_item_2 STRING COMMENT '2nd most commonly co-purchased item.',
    top_item_3 STRING COMMENT '3rd most commonly co-purchased item.',

    CONSTRAINT valid_champion_name EXPECT (champion_name IS NOT NULL) ON VIOLATION DROP ROW,
    CONSTRAINT valid_item_name EXPECT (item_name IS NOT NULL) ON VIOLATION DROP ROW,

    CONSTRAINT item_recommendations_pkey PRIMARY KEY (champion_name, item_name)
)
COMMENT '[gold] Item statistics and recommendations, aggregated per champion grain.'
AS
-------------------------------------------------------------------------------------------
-- 01. final_snapshot -> final_snapshot_with_stats (Base)
--     Capture only the last-logged snapshot in player interval data to represent final build.
-------------------------------------------------------------------------------------------
WITH final_snapshot AS (
    SELECT * 
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY match_id, participant_pos_id
                ORDER BY minute DESC
            ) AS rn
        FROM silver.intervals
    )
    WHERE rn = 1
),

final_snapshot_with_stats AS (
    SELECT
        -- Join key
        fs.match_id,
        fs.participant_pos_id,
        -- Context
        (ps.team = mat.winning_team) AS win,
        ps.champion_name,
        -- Last-interval KDA
        fs.kills,
        fs.deaths,
        fs.assists,
        -- Item Build
        ARRAY_SORT(
            FILTER(
                ARRAY(fs.item_0, fs.item_1, fs.item_2, fs.item_3, fs.item_4, fs.item_5, fs.item_6),
                x -> x IS NOT NULL
            )
        ) AS item_build
    FROM final_snapshot AS fs
    JOIN silver.matches AS mat
        ON mat.match_id = fs.match_id
    JOIN silver.players AS ps
        ON ps.match_id = fs.match_id
        AND ps.participant_pos_id = fs.participant_pos_id
),
-------------------------------------------------------------------------------------------
-- 02. flattened_items
--     Break up item's build array and stitch back per player's last logged interval.
-------------------------------------------------------------------------------------------
flattened_items AS (
    SELECT
        fs.match_id,
        fs.participant_pos_id,
        fs.win,
        fs.champion_name,
        fs.kills,
        fs.deaths,
        fs.assists,
        item_id
    FROM final_snapshot_with_stats AS fs
    LATERAL VIEW EXPLODE(fs.item_build) AS item_id
),
-------------------------------------------------------------------------------------------
-- 03. flattened_items_with_ref:
--     a. Attach a numeric tier_rank encoding item-upgrade hierarchy (low -> high):
--     1 Trinket -> 2 Consumable -> 3 Starter -> 4 Basic -> 5 Boots -> 6 Epic -> 7 Legendary
--     b. An item only recommends alongside items of the SAME rank or HIGHER
--     (e.g. Basic recommends Basic/Boots/Epic/Legendary, but Legendary only recommends other Legendaries).
-------------------------------------------------------------------------------------------
flattened_items_with_ref AS (
    SELECT
        fi.*,
        ir.item_name,
        ir.item_category,
        -- Rank item's category for recommendation system (only recommend equal or higher rank items)
        CASE ir.item_category
            WHEN 'Trinket' THEN 1
            WHEN 'Consumable' THEN 2
            WHEN 'Starter' THEN 3
            WHEN 'Basic' THEN 4
            WHEN 'Boots' THEN 5
            WHEN 'Epic' THEN 6
            WHEN 'Legendary' THEN 7
            -- Excluding categories ('Other', 'Distributed', 'Legacy'). These do not get recommendations.
            ELSE NULL
        END AS tier_rank
    FROM flattened_items AS fi
    LEFT JOIN (
        SELECT * 
        FROM silver.items_ref 
        WHERE __END_AT IS NULL
    ) AS ir
        ON ir.item_id = fi.item_id
),
-------------------------------------------------------------------------------------------
-- 04. item_stats -> total_players_by_champion
--     Aggregated stats per champion-item grain (keyed by item_id) + total champion
--     picks across all players in matches.
-------------------------------------------------------------------------------------------
item_stats AS (
    SELECT
        champion_name,
        item_id,
        COUNT(*) AS players_purchased,
        SUM(IF(win, 1, 0)) AS wins_with_item,
        ROUND(
            AVG((kills + assists) / (deaths + 1))
        , 2) AS avg_kda
    FROM flattened_items_with_ref
    GROUP BY champion_name, item_id
),

total_players_by_champion AS (
    SELECT
        fs.champion_name,
        COUNT(*) AS total_player_picks
    FROM final_snapshot_with_stats AS fs
    GROUP BY fs.champion_name
),
-------------------------------------------------------------------------------------------
-- 05. co_occurrence
--     Recommendations are two-ways for items of equal ranks
--     e.g Infinity Edge <--> Rapid Firecannon (intended)
--     One way for items of lower to higher ranks
--     e.g Doran's Blade --> Infinity Edge (does not make sense reverse)
-------------------------------------------------------------------------------------------
items_per_player AS (
    SELECT
        champion_name,
        match_id,
        participant_pos_id,
        ARRAY_SORT(
            COLLECT_LIST(STRUCT(item_id AS id, tier_rank AS tier)),
            (l, r) -> CASE
                WHEN l.tier < r.tier THEN -1
                WHEN l.tier > r.tier THEN 1
                WHEN l.id < r.id THEN -1
                WHEN l.id > r.id THEN 1
                ELSE 0
            END
        ) AS items
    FROM flattened_items_with_ref
    WHERE tier_rank IS NOT NULL
    GROUP BY champion_name, match_id, participant_pos_id
),

co_occurrence AS (
    SELECT
        ipp.champion_name,
        l.id AS item_id,
        r.id AS co_item_id,
        COUNT(*) AS co_purchase_count
    FROM items_per_player AS ipp
    LATERAL VIEW EXPLODE(ipp.items) AS l
    LATERAL VIEW EXPLODE(ipp.items) AS r
    WHERE l.id != r.id
        AND l.tier <= r.tier
    GROUP BY ipp.champion_name, l.id, r.id
),
-------------------------------------------------------------------------------------------
-- 06. top3_wide
--     Format top three recommendations into wide format
-------------------------------------------------------------------------------------------
co_occurrence_ranked AS (
    SELECT
        co.champion_name,
        co.item_id,
        ir.item_name AS co_item_name,
        ROW_NUMBER() OVER (
            PARTITION BY co.champion_name, co.item_id
            ORDER BY co.co_purchase_count DESC, ir.item_name
        ) AS co_rank
    FROM co_occurrence AS co
    LEFT JOIN (
        SELECT * 
        FROM silver.items_ref 
        WHERE __END_AT IS NULL
    ) AS ir
        ON ir.item_id = co.co_item_id
),

top3_wide AS (
    SELECT
        champion_name,
        item_id,
        -- Top 3
        MAX(IF(co_rank = 1, co_item_name, NULL)) AS top_item_1,
        MAX(IF(co_rank = 2, co_item_name, NULL)) AS top_item_2,
        MAX(IF(co_rank = 3, co_item_name, NULL)) AS top_item_3
    FROM co_occurrence_ranked
    WHERE co_rank <= 3
    GROUP BY champion_name, item_id
),
-------------------------------------------------------------------------------------------
-- 07. first_purchase:
--     Most common first purchase time interval for items, grouped by champion-item
-------------------------------------------------------------------------------------------
item_appearances AS (
    SELECT
        pi.match_id,
        pi.participant_pos_id,
        pi.minute,
        item_id
    FROM silver.intervals AS pi
    LATERAL VIEW EXPLODE(
        FILTER(
            ARRAY(pi.item_0, pi.item_1, pi.item_2, pi.item_3, pi.item_4, pi.item_5, pi.item_6),
            x -> x IS NOT NULL
        )
    ) AS item_id
),

first_purchase AS (
    SELECT
        ia.match_id,
        ia.participant_pos_id,
        ia.item_id,
        MIN(ia.minute) AS first_minute
    FROM item_appearances AS ia
    INNER JOIN (
        SELECT * 
        FROM silver.items_ref 
        WHERE __END_AT IS NULL
    ) AS ir
        ON ir.item_id = ia.item_id
    WHERE ir.item_category NOT IN ('Other', 'Legacy', 'Distributed')
    GROUP BY ia.match_id, ia.participant_pos_id, ia.item_id
),

first_purchase_counts AS (
    SELECT
        ps.champion_name,
        fp.item_id,
        fp.first_minute,
        COUNT(*) AS cnt
    FROM first_purchase AS fp
    JOIN silver.players AS ps
        ON ps.match_id = fp.match_id
        AND ps.participant_pos_id = fp.participant_pos_id
    GROUP BY ps.champion_name, fp.item_id, fp.first_minute
),

most_common_first_purchase_ranked AS (
    SELECT
        champion_name,
        item_id,
        first_minute AS most_common_first_purchase_minute,
        ROW_NUMBER() OVER (
            PARTITION BY champion_name, item_id
            ORDER BY cnt DESC, first_minute
        ) AS rn
    FROM first_purchase_counts
),

most_common_first_purchase AS (
    SELECT champion_name, item_id, most_common_first_purchase_minute
    FROM most_common_first_purchase_ranked
    WHERE rn = 1
),
-------------------------------------------------------------------------------------------
-- 08. item_stats_final
-------------------------------------------------------------------------------------------
item_stats_final AS (
    SELECT
        is_.champion_name,
        ir.item_name AS item_name,
        ir.item_category,
        ROUND(COALESCE(
            is_.players_purchased / NULLIF(tp.total_player_picks, 0)
        , 0), 4) AS player_purchase_rate,
        ROUND(COALESCE(
            is_.wins_with_item / NULLIF(is_.players_purchased, 0)
        , 0), 4) AS win_rate,
        is_.avg_kda,
        mcfp.most_common_first_purchase_minute,
        t3.top_item_1,
        t3.top_item_2,
        t3.top_item_3
    FROM item_stats AS is_
    LEFT JOIN (
        SELECT * 
        FROM silver.items_ref 
        WHERE __END_AT IS NULL
    ) AS ir
        ON ir.item_id = is_.item_id
    JOIN total_players_by_champion AS tp
        ON tp.champion_name = is_.champion_name
    LEFT JOIN top3_wide AS t3
        ON t3.champion_name = is_.champion_name
        AND t3.item_id = is_.item_id
    LEFT JOIN most_common_first_purchase AS mcfp
        ON mcfp.champion_name = is_.champion_name
        AND mcfp.item_id = is_.item_id
)
-------------------------------------------------------------------------------------------
-- Select all above for complete query
-------------------------------------------------------------------------------------------
SELECT
    champion_name,
    item_name,
    item_category,
    player_purchase_rate,
    win_rate,
    avg_kda,
    most_common_first_purchase_minute,
    top_item_1,
    top_item_2,
    top_item_3
FROM item_stats_final
;