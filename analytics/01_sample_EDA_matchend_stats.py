# Databricks notebook source
# /// script
# [tool.databricks.environment]
# environment_version = "5"
# ///
# DBTITLE 1,Overview: Match-End Player Statistics
# MAGIC %md
# MAGIC # EDA: Match-End Player Statistics
# MAGIC
# MAGIC The `gold.matchend_player_stats` table captures performance metrics for every participant in recorded League of Legends matches. Each row represents one player in one match, identified by `match_id` and `participant_pos_id` (position 1-5 for Blue side, 6-10 for Red side).
# MAGIC
# MAGIC ## Content
# MAGIC
# MAGIC 1. Check data quality: completeness, uniqueness, and staleness of the underlying records
# MAGIC 2. Measure competitive balance across side (Blue/Red) and role
# MAGIC 3. Benchmark performance (KDA, CS) by role
# MAGIC 4. Examine how economy (gold) relates to match outcome
# MAGIC 5. Surface the strongest correlates of winning
# MAGIC 6. Land on plain-language takeaways for stakeholders
# MAGIC
# MAGIC ## Table Schema
# MAGIC
# MAGIC - `match_id` STRING: match identifier
# MAGIC - `participant_pos_id` INT (1-5 = Blue side, 6-10 = Red side)
# MAGIC - `game_duration` INT (match length in seconds)
# MAGIC - `team` STRING ('Blue' or 'Red')
# MAGIC - `win` BOOLEAN (whether this player's team won)
# MAGIC - `champion_name` STRING
# MAGIC - `champion_role` STRING (resolved role: top/jungle/mid/adc/support)
# MAGIC - `level` INT (end-of-match champion level)
# MAGIC - `kills` INT, `deaths` INT, `assists` INT
# MAGIC - `cs` INT (combined lane + jungle creep score)
# MAGIC - `total_gold` INT (cumulative gold earned)
# MAGIC - `item_build` ARRAY<STRING> (final item names)
# MAGIC - `unlogged_duration` INT (seconds between last logged 5-minute interval and actual match end)
# MAGIC
# MAGIC **A note on data quality:** stats reflect the last logged 5-minute sampling interval, not the precise moment the match ended. `unlogged_duration` measures the gap, in seconds, between the last logged interval and actual match end. Higher values mean: staler records, potentially missing final skirmishes, item purchases, or level-ups.

# COMMAND ----------

# DBTITLE 1,Import dependencies
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

sns.set_theme(style='dark')

# COMMAND ----------

# DBTITLE 1,Set context
# MAGIC %sql
# MAGIC USE CATALOG league_records;
# MAGIC
# MAGIC USE SCHEMA gold;

# COMMAND ----------

# DBTITLE 1,SOURCE
SOURCE = spark.sql("""
SELECT *
FROM matchend_player_stats
;
""").toPandas()

# COMMAND ----------

# DBTITLE 1,Data Quality Assessment
# MAGIC %md
# MAGIC ## Data Quality Check
# MAGIC
# MAGIC Before analyzing outcomes and performance patterns, we check three things: completeness (missing values), uniqueness (does the primary key hold), and staleness (how many records have a high `unlogged_duration`).
# MAGIC

# COMMAND ----------

# DBTITLE 1,display(SOURCE.head())
display(SOURCE.head())

# COMMAND ----------

# DBTITLE 1,def data_quality_summary()
def data_quality_summary(df, show_plots: bool = False) -> tuple | None:
    # ----- Row count
    total_rows = len(df)
    total_matches = df['match_id'].nunique()
    print(f"Total rows: {total_rows:,}")
    print(f"Total unique matches: {total_matches:,}")

    # ----- Null rate
    null_pct = (df.isnull().mean() * 100).sort_values(ascending=False)
    null_pct = null_pct[null_pct > 0]
    print("\n=== Null Rate by Column ===")
    print(null_pct.to_string() if len(null_pct) > 0 else "No null values detected in any column")

    # ----- Duplicate key check
    duplicate_keys = df.duplicated(subset=['match_id', 'participant_pos_id']).sum()
    print("\n=== Primary Key Check ===")
    print(f"Duplicate (match_id, participant_pos_id) pairs: {duplicate_keys}")

    # ----- Staleness check
    stale_threshold = 120
    stale_pct = (df['unlogged_duration'] > stale_threshold).mean() * 100
    median_staleness = df['unlogged_duration'].median()

    print(f"Median unlogged_duration: {median_staleness:.0f} seconds")
    print(f"Rows with >120s staleness: {stale_pct:.1f}%")

    if not show_plots:
        return None
    
    fig, ax = plt.subplots(figsize=(12, 5), dpi=200)
    sns.histplot(
        df['unlogged_duration'], 
        bins=50, 
        color='steelblue', 
        edgecolor='black',
        ax=ax,
    )
    ax.axvline(x=120, color='red', linestyle='--', linewidth=2, label='120s threshold')

    ax.set_xlabel('Unlogged Duration (seconds)')
    ax.set_ylabel('Frequency')
    ax.set_title('Distribution of Staleness (unlogged_duration)')
    ax.legend()

    return fig, ax

data_quality_summary(SOURCE, show_plots=True)


# COMMAND ----------

# MAGIC %md
# MAGIC **Data Quality Takeaway**  
# MAGIC The matchend_player_stats table is structurally sound with unique keys and minimal missing values. However, a notable share of records have >2 minutes of staleness (`unlogged_duration`), meaning end-game stats may not fully capture the final moments. Fortunately, a primary share of the dataset are fully logged.

# COMMAND ----------

# DBTITLE 1,Win Rate & Competitive Balance
# MAGIC %md
# MAGIC ## Aggregated Win Rate % Balance
# MAGIC
# MAGIC Structural asymmetries can create unfair advantages in competitive team games. Blue vs Red side may carry map or draft advantages, and certain roles may have outsized impact on win probability. 

# COMMAND ----------

# DBTITLE 1,def win_rate_by()
def win_rate_by(
    src: pd.DataFrame, 
    group_col: str,
    show_plots: bool = False
) -> pd.DataFrame:
    win_rate_df = (src
        .groupby(group_col)['win']
        .mean()
        .mul(100)
        .rename('win_rate')
        .reset_index()
        .sort_values('win_rate', ascending=False)
    )
    if not show_plots:
        return win_rate_df
    
    fig, ax = plt.subplots(figsize=(8, 5), dpi=200)
    sns.barplot(
        data=win_rate_df,
        y=group_col, 
        x='win_rate', 
        hue=group_col,
    )
    ax.axvline(x=50, color='red', linestyle='--', linewidth=1.5, label='50% baseline')

    ax.set_title(f'Win Rate (%) by {group_col}')
    ax.set_xlabel('Win Rate (%)')
    ax.set_ylabel(group_col)
    ax.legend()

    return win_rate_df

win_rate_by(SOURCE, 'team', show_plots=True)

# COMMAND ----------

# MAGIC %md
# MAGIC **BLUE vs RED Win Rate Takeaway**  
# MAGIC Blue and Red sides show near-equal win rates, indicating fair structural balance with no significant side advantage.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Roles Economy Balance 
# MAGIC Roles in LoL have fundamentally different performance profiles:
# MAGIC
# MAGIC - **Carry roles (ADC, Mid, Top):** Typically post higher CS and accumulate more gold.
# MAGIC - **Support:** Prioritizes assists and vision control over personal economy.
# MAGIC - **Jungle:** Balances farming (CS) with map pressure and objective control.
# MAGIC
# MAGIC We benchmark two key signals:
# MAGIC 1. `KDA_ratio` **(Kills + Assists) / (Deaths + 1)**, a composite metric of combat effectiveness.
# MAGIC 2. `CS` **(minion CS + jungle CS)**, a measure of farming efficiency.
# MAGIC
# MAGIC Boxplots reveal not just central tendency, but also performance variance within each role. Wide variance suggests high skill expression or champion diversity; narrow variance indicates standardized performance.

# COMMAND ----------

# DBTITLE 1,def kda_by()
def kda_by(
    df: pd.DataFrame, 
    group_col: str, 
    show_plots: bool = False
) -> pd.DataFrame:
    df = df.assign(
        kda_ratio=(df['kills'] + df['assists']) / (df['deaths'] + 1)
    )
    
    agg_kda_stats = (df           
        .groupby(group_col)['kda_ratio']
        .agg(['median', 'std', 'count'])
        .sort_values('std', ascending=False)
    )

    if not show_plots:
        return agg_kda_stats
    
    fig, ax = plt.subplots(figsize=(10, 6))
    sns.boxplot(
        data=df,
        x=group_col, 
        y='kda_ratio', 
        hue=group_col, 
        showfliers=False,
        ax=ax
    )
    ax.set_ylabel('KDA Ratio')
    ax.set_xlabel(group_col)
    ax.set_title(f'KDA Ratio Distribution by {group_col} (outliers removed for clarity)')

    ax.axhline(
        y=df['kda_ratio'].median(), 
        color='green', 
        linestyle='--', 
        linewidth=1, 
        label='Overall median'
    )
    ax.legend()

    return agg_kda_stats

kda_by(SOURCE, 'champion_role', show_plots=True)

# COMMAND ----------

# DBTITLE 1,def cs_by()
def cs_by(df: pd.DataFrame, group_col: str, show_plots: bool = False):
    agg_cs_stats = (df
        .groupby(group_col)['cs']
        .agg(['median', 'mean', 'count'])
        .sort_values('median', ascending=False)
    )

    if not show_plots:
        return agg_cs_stats
    
    fig, ax = plt.subplots(figsize=(12, 6))
    sns.boxplot(
        data=df, 
        x=group_col, 
        y='cs', 
        hue=group_col, 
        showfliers=False, 
        ax=ax
    )
    ax.set_ylabel('CS')
    ax.set_xlabel(group_col)
    ax.set_title(f'CS Distribution by {group_col} (outliers removed for clarity)')

    ax.axhline(
        y=df['cs'].median(), 
        color='purple', 
        linestyle='--', 
        linewidth=1, 
        label='Overall median'
    )
    ax.legend()

    return agg_cs_stats

cs_by(SOURCE, 'champion_role', show_plots=True)

# COMMAND ----------

# MAGIC %md
# MAGIC **Role Performance Takeaway**  
# MAGIC 1. `KDA_ratio` Top has the lowest KDA ratio, Support has the highest KDA ratio. The difference between these two, and among the five roles in general, are still within <1 kda_ratio. 
# MAGIC 2. `CS` Support CS distribution has very little variance, and tightly hug around the 0-50 range. All other roles, as expected, are overall very even to one another variance wise and median wise.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Economy vs Outcome
# MAGIC
# MAGIC Gold converts directly into power through items and stat scaling. If gold is a strong predictor of victory:
# MAGIC  winning players should show systematically higher gold accumulation.

# COMMAND ----------

# DBTITLE 1,def scatter_stats()
def scatter_stats(
    df: pd.DataFrame, 
    x: str,
    y: str,
    hue: str = None,
    pct: float = 0.1,
    seed: int = 42
):
    df = df.sample(frac=pct, random_state=seed)[[x, y, hue]]
    fig, ax = plt.subplots(figsize=(12, 6))
    sns.scatterplot(
        data=df,
        x=x, 
        y=y, 
        hue=hue or x, 
        alpha=0.6, 
        s=30, 
        ax=ax
    )
    ax.set_xlabel(x)
    ax.set_ylabel(y)
    ax.set_title(f'{x} vs {y} ({pct * 100:.2f}% sample)')

    ax.legend(title=hue, labels=[*df[hue].unique()])

    print(f"=== {x}-{y} Relationship ===")
    corr = df[[x, y]].corr().iloc[0, 1]
    print(f"Correlation ({x} vs {y}): {corr:.3f}")
    if corr > 0.5:
        print(f"✓ Strong positive correlation between {x} and {y}.")
    else:
        print(f"✓ Moderate correlation between {x} and {y}.")

# COMMAND ----------

# DBTITLE 1,scatter_stats(kills, total_gold, win)
scatter_stats(SOURCE, 'kills', 'total_gold', hue='win', pct=0.1)

# COMMAND ----------

# DBTITLE 1,scatter_stats(cs, total_gold, win)
scatter_stats(SOURCE, 'cs', 'total_gold', 'win')

# COMMAND ----------

# DBTITLE 1,def gold_per_minute_plot()
def gold_per_minute_plot(df: pd.DataFrame, show_plots: bool = True):
    df = (df
        .assign(gold_per_min=df['total_gold'] / (df['game_duration'] / 60))
        [['gold_per_min', 'win']]
    )
    agg_df = (df
        .groupby('win')['gold_per_min']
        .agg(['mean', 'median', 'std'])
    )
    print("\n=== Gold Economy & Win Probability ===")
    win_gpm = agg_df.loc[True, 'median']
    loss_gpm = agg_df.loc[False, 'median']
    gpm_diff =  agg_df.loc[True, 'median'] - loss_gpm
    gpm_diff_pct = (gpm_diff / loss_gpm) * 100
    if gpm_diff > 0:
        print(f"\n✓ Winning players earn {gpm_diff:.0f} GPM more than losing players (median), a {gpm_diff_pct:.1f}% advantage.")
    else:
        print(f"\n✗ Losing players earn {abs(gpm_diff):.0f} GPM more than winning players (median), a {abs(gpm_diff_pct):.1f}% disadvantage.")

    if not show_plots:
        return agg_df

    fig, ax = plt.subplots(figsize=(10, 6))
    sns.violinplot(
        data=df,
        x='win',
        y='gold_per_min', 
        hue='win', 
        inner='quartile', 
        ax=ax
    )
    ax.set_xlabel('Match Outcome')
    ax.set_ylabel('Gold Per Minute (GPM)')
    ax.set_title('Gold-Per-Minute Distribution by Win/Loss')

    ax.set_xticks([0, 1])
    ax.set_xticklabels(['Loss', 'Win'])

    return agg_df

gold_per_minute_plot(SOURCE, show_plots=True)

# COMMAND ----------

# DBTITLE 1,Correlation Analysis: What Drives Wins?
# MAGIC %md
# MAGIC ## Correlation View: Identifying Win Drivers
# MAGIC
# MAGIC **Correlation analysis** reveals which performance dimensions move together and which most strongly predict victory using a correlation heatmap.

# COMMAND ----------

# DBTITLE 1,Correlation Heatmap
def correlation_heatmap(df, corr_cols=None):
    if corr_cols is None:
        corr_cols = ['kills', 'deaths', 'assists', 'cs', 'total_gold', 'level', 'win']

    df = (df[corr_cols]
        .assign(win=df['win'].astype('int64'))
    )
    corr_matrix = df.corr()
    fig, ax = plt.subplots(figsize=(10, 8))
    sns.heatmap(
        corr_matrix, annot=True, fmt='.2f', cmap='coolwarm', center=0, 
        square=True, linewidths=1, cbar_kws={"shrink": 0.8}, ax=ax
    )
    ax.set_title('Correlation Matrix: Performance Metrics & Win Outcome')

    print("\n=== Strongest Correlates of Winning ===")
    win_corrs = (corr_matrix['win']
        .drop('win')
        .sort_values(ascending=False)
    )
    print(f"\n✓ Top positive predictor: {win_corrs.index[0]} (r={win_corrs.iloc[0]:.3f})")
    print(f"✓ Top negative predictor: {win_corrs.index[-1]} (r={win_corrs.iloc[-1]:.3f})")

correlation_heatmap(SOURCE)

# COMMAND ----------

# DBTITLE 1,Executive Summary
# MAGIC %md
# MAGIC ## Executive Summary
# MAGIC
# MAGIC * **Data Quality**: The table maintains strong structural integrity (unique keys, minimal nulls). However, staleness remains a concern.  Downstream analyses should account for this when interpreting final itemization or level scaling. Ensure to use only data that has `unlogged_duration` = 0, or otherwise account for the staleness in their analysis.
# MAGIC
# MAGIC * **Competitive Balance**: Side balance (Blue vs Red) appears fair, with win rates close to 50/50. Role balance shows minor variance but no single role dominates—matchmaking.
# MAGIC
# MAGIC * **Performance Variance**: Roles exhibit predictable patterns—carry roles (ADC, Mid) show high CS and gold, while support shows low CS but high assist rates. KDA variance differs by role, with some positions (e.g., jungle, top) showing wider spreads.
# MAGIC
# MAGIC * **Economy as a Win Driver**: Winning players earn higher gold-per-minute median, significance testing still needs to be done to confirm this is not due to sampling chance.
# MAGIC
# MAGIC * **Correlation Insights**: Kills, gold, and level show strong positive correlation with winning, while deaths show the strongest negative correlation.