# ==============================================================================
# File: R/09_matchup_analysis.R
# Project: A Comparative Study of ML Models for Explainable IPL Match Outcome Prediction
# Description: Batter vs. Bowler Head-to-Head Micro-Matchup Analytics Engine
#              Computes granular historical encounters, phase splits, dismissal
#              telemetry, bowler dominance, recent form, and statistical significance.
# ==============================================================================

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
})

# Path to SQLite database
get_db_con <- function(db_path = "database/ipl_database.sqlite") {
  if (!file.exists(db_path)) {
    # Check parent dir
    if (file.exists(file.path("..", db_path))) {
      db_path <- file.path("..", db_path)
    } else {
      stop(sprintf("Database file not found at: %s", db_path))
    }
  }
  dbConnect(SQLite(), db_path)
}

# ------------------------------------------------------------------------------
# 1. Fuzzy Player Name Resolver
# ------------------------------------------------------------------------------
resolve_player_name <- function(con, input_name, role = c("batter", "bowler")) {
  role <- match.arg(role)
  tbl_col <- role
  
  # Clean input
  query_str <- trimws(input_name)
  
  # 1. Exact match check
  q_exact <- sprintf("SELECT DISTINCT %s FROM deliveries WHERE %s = '%s' LIMIT 1;", 
                     tbl_col, tbl_col, gsub("'", "''", query_str))
  exact_res <- dbGetQuery(con, q_exact)
  if (nrow(exact_res) > 0 && !is.na(exact_res[[1]][1])) {
    return(exact_res[[1]][1])
  }
  
  # 2. Case-insensitive exact match
  q_ci <- sprintf("SELECT DISTINCT %s FROM deliveries WHERE LOWER(%s) = LOWER('%s') LIMIT 1;", 
                  tbl_col, tbl_col, gsub("'", "''", query_str))
  ci_res <- dbGetQuery(con, q_ci)
  if (nrow(ci_res) > 0 && !is.na(ci_res[[1]][1])) {
    return(ci_res[[1]][1])
  }
  
  # 3. Token-based / Substring fuzzy search ordered by total deliveries/balls
  # Split input words (e.g. "Virat Kohli" -> "Virat", "Kohli")
  tokens <- strsplit(query_str, "\\s+")[[1]]
  tokens <- tokens[nchar(tokens) > 1]
  
  like_clauses <- paste0("LOWER(", tbl_col, ") LIKE '%", tolower(tokens), "%'", collapse = " OR ")
  q_fuzzy <- sprintf("
    SELECT %s, COUNT(*) AS ball_count 
    FROM deliveries 
    WHERE %s 
    GROUP BY %s 
    ORDER BY ball_count DESC;
  ", tbl_col, like_clauses, tbl_col)
  
  fuzzy_res <- dbGetQuery(con, q_fuzzy)
  
  if (nrow(fuzzy_res) > 0) {
    # If one of the tokens matches last name exactly
    last_word <- tolower(tokens[length(tokens)])
    exact_surname <- fuzzy_res %>% 
      filter(grepl(paste0("\\b", last_word, "$"), tolower(get(tbl_col))))
    
    if (nrow(exact_surname) > 0) {
      return(exact_surname[[tbl_col]][1])
    }
    return(fuzzy_res[[tbl_col]][1])
  }
  
  return(NULL)
}

# ------------------------------------------------------------------------------
# 2. Comprehensive Matchup Analytics Core
# ------------------------------------------------------------------------------
analyze_matchup <- function(batter_name, 
                            bowler_name, 
                            venue_name = NULL, 
                            current_over = NULL, 
                            recent_window_seasons = c("2022", "2023", "2024"),
                            db_path = "database/ipl_database.sqlite",
                            verbose = TRUE) {
  
  con <- get_db_con(db_path)
  on.exit(dbDisconnect(con))
  
  # Resolve names
  clean_batter <- resolve_player_name(con, batter_name, "batter")
  clean_bowler <- resolve_player_name(con, bowler_name, "bowler")
  
  if (is.null(clean_batter)) {
    stop(sprintf("Could not find batter matching '%s' in IPL records.", batter_name))
  }
  if (is.null(clean_bowler)) {
    stop(sprintf("Could not find bowler matching '%s' in IPL records.", bowler_name))
  }
  
  # ----------------------------------------------------------------------------
  # A. Head-to-Head Overall Metrics
  # ----------------------------------------------------------------------------
  q_h2h <- sprintf("
    SELECT 
      COUNT(*) AS total_deliveries,
      COUNT(CASE WHEN extras_type != 'wides' OR extras_type IS NULL OR extras_type = '' THEN 1 END) AS balls_faced,
      COUNT(CASE WHEN extras_type NOT IN ('wides', 'noballs') OR extras_type IS NULL OR extras_type = '' THEN 1 END) AS legal_balls_bowled,
      COALESCE(SUM(batsman_runs), 0) AS runs_scored,
      COALESCE(SUM(batsman_runs + CASE WHEN extras_type IN ('wides', 'noballs') THEN extra_runs ELSE 0 END), 0) AS runs_conceded,
      COUNT(CASE WHEN is_wicket = 1 AND player_dismissed = '%s' AND dismissal_kind IN ('caught', 'bowled', 'lbw', 'stumped', 'caught and bowled', 'hit wicket') THEN 1 END) AS dismissals,
      COUNT(CASE WHEN batsman_runs = 0 AND (extras_type != 'wides' OR extras_type IS NULL OR extras_type = '') THEN 1 END) AS dot_balls,
      COUNT(CASE WHEN batsman_runs = 1 THEN 1 END) AS singles,
      COUNT(CASE WHEN batsman_runs = 2 THEN 1 END) AS twos,
      COUNT(CASE WHEN batsman_runs = 3 THEN 1 END) AS threes,
      COUNT(CASE WHEN batsman_runs = 4 THEN 1 END) AS fours,
      COUNT(CASE WHEN batsman_runs = 6 THEN 1 END) AS sixes,
      COUNT(CASE WHEN extras_type = 'wides' THEN 1 END) AS wides,
      COUNT(CASE WHEN extras_type = 'noballs' THEN 1 END) AS noballs
    FROM deliveries
    WHERE batter = '%s' AND bowler = '%s';
  ", clean_batter, clean_batter, clean_bowler)
  
  h2h <- dbGetQuery(con, q_h2h)
  
  # Sample size check
  balls_faced <- h2h$balls_faced
  runs_scored <- h2h$runs_scored
  dismissals <- h2h$dismissals
  dots <- h2h$dot_balls
  fours <- h2h$fours
  sixes <- h2h$sixes
  boundaries <- fours + sixes
  boundary_runs <- (fours * 4) + (sixes * 6)
  singles <- h2h$singles
  twos <- h2h$twos
  threes <- h2h$threes
  rotations <- singles + twos + threes
  rotation_runs <- singles + (twos * 2) + (threes * 3)
  runs_conceded <- h2h$runs_conceded
  legal_bowled <- h2h$legal_balls_bowled
  
  # Derived metrics
  bat_sr <- ifelse(balls_faced > 0, round((runs_scored / balls_faced) * 100, 2), 0.0)
  bat_avg <- ifelse(dismissals > 0, round(runs_scored / dismissals, 2), NA)
  balls_per_dismissal <- ifelse(dismissals > 0, round(balls_faced / dismissals, 1), NA)
  dot_pct <- ifelse(balls_faced > 0, round((dots / balls_faced) * 100, 2), 0.0)
  boundary_pct <- ifelse(balls_faced > 0, round((boundaries / balls_faced) * 100, 2), 0.0)
  boundary_runs_pct <- ifelse(runs_scored > 0, round((boundary_runs / runs_scored) * 100, 2), 0.0)
  rotation_pct <- ifelse(balls_faced > 0, round((rotations / balls_faced) * 100, 2), 0.0)
  
  bowler_econ <- ifelse(legal_bowled > 0, round((runs_conceded / legal_bowled) * 6, 2), 0.0)
  bowler_avg <- ifelse(dismissals > 0, round(runs_conceded / dismissals, 2), NA)
  bowler_sr <- ifelse(dismissals > 0, round(legal_bowled / dismissals, 1), NA)
  
  # ----------------------------------------------------------------------------
  # B. Sample Size & Statistical Significance Classification
  # ----------------------------------------------------------------------------
  sample_size_tier <- if (balls_faced >= 45) {
    "Statistically Robust Sample (High Confidence, N >= 45 balls)"
  } else if (balls_faced >= 20) {
    "Moderate Sample Size (Moderate Confidence, 20-44 balls)"
  } else if (balls_faced >= 10) {
    "Small Sample Size (Indicative Trend Only, 10-19 balls)"
  } else if (balls_faced > 0) {
    "Micro / Anecdotal Sample (High Variance — Interpret with Caution, < 10 balls)"
  } else {
    "No Historical Head-to-Head Encounters in IPL Database"
  }
  
  # ----------------------------------------------------------------------------
  # C. Dismissal Modes Breakdown
  # ----------------------------------------------------------------------------
  q_dism <- sprintf("
    SELECT dismissal_kind, COUNT(*) AS count
    FROM deliveries
    WHERE batter = '%s' AND bowler = '%s'
      AND is_wicket = 1 AND player_dismissed = '%s'
      AND dismissal_kind IN ('caught', 'bowled', 'lbw', 'stumped', 'caught and bowled', 'hit wicket')
    GROUP BY dismissal_kind
    ORDER BY count DESC;
  ", clean_batter, clean_bowler, clean_batter)
  dism_df <- dbGetQuery(con, q_dism)
  
  # ----------------------------------------------------------------------------
  # D. Phase-by-Phase Breakdown (Powerplay, Middle, Death)
  # ----------------------------------------------------------------------------
  q_phase <- sprintf("
    SELECT 
      CASE 
        WHEN over BETWEEN 0 AND 5 THEN 'Powerplay (Overs 1-6)'
        WHEN over BETWEEN 6 AND 14 THEN 'Middle Overs (Overs 7-15)'
        ELSE 'Death Overs (Overs 16-20)'
      END AS phase,
      COUNT(CASE WHEN extras_type != 'wides' OR extras_type IS NULL OR extras_type = '' THEN 1 END) AS balls,
      COALESCE(SUM(batsman_runs), 0) AS runs,
      COUNT(CASE WHEN is_wicket = 1 AND player_dismissed = '%s' AND dismissal_kind IN ('caught', 'bowled', 'lbw', 'stumped', 'caught and bowled', 'hit wicket') THEN 1 END) AS wickets,
      COUNT(CASE WHEN batsman_runs = 0 AND (extras_type != 'wides' OR extras_type IS NULL OR extras_type = '') THEN 1 END) AS dots,
      COUNT(CASE WHEN batsman_runs = 4 THEN 1 END) AS fours,
      COUNT(CASE WHEN batsman_runs = 6 THEN 1 END) AS sixes
    FROM deliveries
    WHERE batter = '%s' AND bowler = '%s'
    GROUP BY phase
    ORDER BY MIN(over);
  ", clean_batter, clean_batter, clean_bowler)
  phase_df <- dbGetQuery(con, q_phase)
  if (nrow(phase_df) > 0) {
    phase_df <- phase_df %>%
      mutate(
        strike_rate = ifelse(balls > 0, round((runs / balls) * 100, 2), 0.0),
        dot_pct = ifelse(balls > 0, round((dots / balls) * 100, 1), 0.0),
        boundaries = fours + sixes
      )
  }
  
  # ----------------------------------------------------------------------------
  # E. Era / Recency Breakdown (Historical vs Recent 2022-2024)
  # ----------------------------------------------------------------------------
  recent_seasons_sql <- paste0("'", recent_window_seasons, "'", collapse = ",")
  q_era <- sprintf("
    SELECT 
      CASE 
        WHEN m.season IN (%s) THEN 'Recent Era (%s)'
        ELSE 'Career Baseline (2008-2021)'
      END AS era,
      COUNT(CASE WHEN d.extras_type != 'wides' OR d.extras_type IS NULL OR d.extras_type = '' THEN 1 END) AS balls,
      COALESCE(SUM(d.batsman_runs), 0) AS runs,
      COUNT(CASE WHEN d.is_wicket = 1 AND d.player_dismissed = '%s' AND d.dismissal_kind IN ('caught', 'bowled', 'lbw', 'stumped', 'caught and bowled', 'hit wicket') THEN 1 END) AS wickets,
      COUNT(CASE WHEN d.batsman_runs = 0 AND (d.extras_type != 'wides' OR d.extras_type IS NULL OR d.extras_type = '') THEN 1 END) AS dots,
      COUNT(CASE WHEN d.batsman_runs IN (4, 6) THEN 1 END) AS boundaries
    FROM deliveries d
    JOIN matches m ON d.match_id = m.id
    WHERE d.batter = '%s' AND d.bowler = '%s'
    GROUP BY era
    ORDER BY era DESC;
  ", recent_seasons_sql, paste(range(recent_window_seasons), collapse = "-"), clean_batter, clean_batter, clean_bowler)
  era_df <- dbGetQuery(con, q_era)
  if (nrow(era_df) > 0) {
    era_df <- era_df %>%
      mutate(
        strike_rate = ifelse(balls > 0, round((runs / balls) * 100, 2), 0.0),
        dot_pct = ifelse(balls > 0, round((dots / balls) * 100, 1), 0.0)
      )
  }
  
  # ----------------------------------------------------------------------------
  # F. Overall Recent Form (Past 2 Seasons: 2023-2024)
  # ----------------------------------------------------------------------------
  # Batter recent form across all bowlers
  q_btr_form <- sprintf("
    SELECT 
      COUNT(DISTINCT d.match_id) AS matches_played,
      COUNT(CASE WHEN d.extras_type != 'wides' THEN 1 END) AS balls,
      COALESCE(SUM(d.batsman_runs), 0) AS runs,
      COUNT(CASE WHEN d.is_wicket = 1 AND d.player_dismissed = '%s' AND d.dismissal_kind IN ('caught', 'bowled', 'lbw', 'stumped', 'caught and bowled', 'hit wicket') THEN 1 END) AS dismissals,
      COUNT(CASE WHEN d.batsman_runs IN (4, 6) THEN 1 END) AS boundaries,
      COUNT(CASE WHEN d.batsman_runs = 0 AND (d.extras_type != 'wides' OR d.extras_type IS NULL) THEN 1 END) AS dots
    FROM deliveries d
    JOIN matches m ON d.match_id = m.id
    WHERE m.season IN ('2023', '2024') AND d.batter = '%s';
  ", clean_batter, clean_batter)
  btr_form <- dbGetQuery(con, q_btr_form)
  
  # Bowler recent form across all batters
  q_bwl_form <- sprintf("
    SELECT 
      COUNT(DISTINCT d.match_id) AS matches_played,
      COUNT(CASE WHEN d.extras_type NOT IN ('wides', 'noballs') THEN 1 END) AS legal_balls,
      COALESCE(SUM(d.batsman_runs + CASE WHEN d.extras_type IN ('wides', 'noballs') THEN d.extra_runs ELSE 0 END), 0) AS runs_conceded,
      COUNT(CASE WHEN d.is_wicket = 1 AND d.dismissal_kind IN ('caught', 'bowled', 'lbw', 'stumped', 'caught and bowled', 'hit wicket') THEN 1 END) AS wickets,
      COUNT(CASE WHEN d.batsman_runs = 0 AND (d.extras_type NOT IN ('wides', 'noballs') OR d.extras_type IS NULL) THEN 1 END) AS dots
    FROM deliveries d
    JOIN matches m ON d.match_id = m.id
    WHERE m.season IN ('2023', '2024') AND d.bowler = '%s';
  ", clean_bowler)
  bwl_form <- dbGetQuery(con, q_bwl_form)
  
  # ----------------------------------------------------------------------------
  # G. Venue Matchup Dynamics
  # ----------------------------------------------------------------------------
  q_venues <- sprintf("
    SELECT 
      m.venue,
      COUNT(CASE WHEN d.extras_type != 'wides' THEN 1 END) AS balls,
      COALESCE(SUM(d.batsman_runs), 0) AS runs,
      COUNT(CASE WHEN d.is_wicket = 1 AND d.player_dismissed = '%s' AND d.dismissal_kind IN ('caught', 'bowled', 'lbw', 'stumped', 'caught and bowled', 'hit wicket') THEN 1 END) AS wickets
    FROM deliveries d
    JOIN matches m ON d.match_id = m.id
    WHERE d.batter = '%s' AND d.bowler = '%s'
    GROUP BY m.venue
    ORDER BY balls DESC
    LIMIT 5;
  ", clean_batter, clean_batter, clean_bowler)
  venues_df <- dbGetQuery(con, q_venues)
  if (nrow(venues_df) > 0) {
    venues_df <- venues_df %>%
      mutate(strike_rate = ifelse(balls > 0, round((runs / balls) * 100, 2), 0.0))
  }
  
  # ----------------------------------------------------------------------------
  # H. Qualitative Tactical Assessments
  # ----------------------------------------------------------------------------
  # Batter Tactical Tendency
  batter_tendency <- if (balls_faced == 0) {
    "No Data (First Career Meeting)"
  } else if (bat_sr >= 150 && (is.na(balls_per_dismissal) || balls_per_dismissal >= 25)) {
    "Aggressive Attack & Dominant Exploitation (High SR, High Boundary %, Rare Dismissal)"
  } else if (bat_sr >= 135 && dismissals <= 2) {
    "Counter-Attacking / Active Boundary Hunting"
  } else if (dot_pct <= 35 && bat_sr >= 115) {
    "Active Strike Rotation & Risk Mitigation (Low Dot %, Consistent Strike Turnover)"
  } else if (bat_sr < 110 && dismissals >= 3) {
    "Severe Struggle & Bunny Dynamic (Low Strike Rate, High Dismissal Vulnerability)"
  } else if (bat_sr < 90) {
    "Ultra-Defensive Containment / Block & Preserve (Extremely Low Risk, Stifled Run Rate)"
  } else {
    "Balanced / Neutral Tactical Accumulation"
  }
  
  # Bowler Dominance Rating
  bowler_dominance <- if (balls_faced == 0) {
    "Uncontested (No Historical Balls Bowled)"
  } else if (dismissals >= 4 && bat_sr <= 115) {
    "Comprehensive Bowler Mastery / Decisive Dominance (Frequent Wickets & Stifled Scoring)"
  } else if (bowler_econ <= 6.5 && dismissals >= 1) {
    "High Economic Choke & Suffocation (Low Economy, Persistent Dot Balls)"
  } else if (bat_sr >= 155 && dismissals <= 1) {
    "Expensive / Under Pressure Against This Batter (High Boundary Leakage, Low Threat)"
  } else if (dismissals >= 3) {
    "Wicket-Taking Edge (Consistently Dismisses Batter Despite Runs Conceded)"
  } else {
    "Balanced Contest / Tactical Stalemate"
  }
  
  # ----------------------------------------------------------------------------
  # I. Console Output Rendering
  # ----------------------------------------------------------------------------
  if (verbose) {
    cat("\n")
    cat("========================================================================================\n")
    cat(sprintf("        BATTER vs. BOWLER HEAD-TO-HEAD MATCHUP ANALYTICS ENGINE (IPL)\n"))
    cat(sprintf("        %s (BAT)  vs.  %s (BOWL)\n", toupper(clean_batter), toupper(clean_bowler)))
    cat("========================================================================================\n")
    cat(sprintf("Sample Reliability : %s\n", sample_size_tier))
    if (!is.null(venue_name)) cat(sprintf("Context Venue      : %s\n", venue_name))
    if (!is.null(current_over)) {
      phase_label <- if (current_over < 6) "Powerplay (Overs 1-6)" else if (current_over < 15) "Middle (Overs 7-15)" else "Death (Overs 16-20)"
      cat(sprintf("Current Match Over : Over %d [%s]\n", current_over, phase_label))
    }
    cat("----------------------------------------------------------------------------------------\n")
    
    # 1. BATTER PROFILE
    cat("\n[1] BATTER'S HISTORICAL PERFORMANCE AGAINST THIS SPECIFIC BOWLER:\n")
    cat(sprintf("  • Balls Faced           : %d legal deliveries (Total deliveries faced: %d)\n", balls_faced, h2h$total_deliveries))
    cat(sprintf("  • Runs Scored           : %d runs\n", runs_scored))
    cat(sprintf("  • Dismissals            : %d times\n", dismissals))
    cat(sprintf("  • Batting Average       : %s\n", ifelse(is.na(bat_avg), "Undefeated / Infinite (0 dismissals)", sprintf("%.2f runs/dismissal", bat_avg))))
    cat(sprintf("  • Batting Strike Rate   : %.2f (Runs per 100 balls)\n", bat_sr))
    cat(sprintf("  • Balls Per Dismissal   : %s\n", ifelse(is.na(balls_per_dismissal), "Never Dismissed", sprintf("%.1f balls", balls_per_dismissal))))
    cat(sprintf("  • Boundaries            : %d (Fours: %d, Sixes: %d) | Boundary Frequency: 1 in %.1f balls\n", 
                boundaries, fours, sixes, ifelse(boundaries > 0, balls_faced / boundaries, 0)))
    cat(sprintf("  • Runs in Boundaries    : %d runs (%.1f%% of total runs scored)\n", boundary_runs, boundary_runs_pct))
    cat(sprintf("  • Dot Balls Faced       : %d (Dot Ball %%: %.2f%%)\n", dots, dot_pct))
    cat(sprintf("  • Strike Rotation       : %d balls (Singles: %d, Twos: %d, Threes: %d) | Rotation %%: %.2f%%\n", 
                rotations, singles, twos, threes, rotation_pct))
    cat(sprintf("  • Batter Tactical Mode  : %s\n", batter_tendency))
    
    # Dismissal modes
    if (nrow(dism_df) > 0) {
      dism_str <- paste(apply(dism_df, 1, function(r) sprintf("%s (%s)", r["dismissal_kind"], r["count"])), collapse = ", ")
      cat(sprintf("  • Dismissal Breakdown   : %s\n", dism_str))
    } else {
      cat("  • Dismissal Breakdown   : Bowler has never dismissed this batter in IPL matches.\n")
    }
    
    # 2. BOWLER PROFILE
    cat("\n[2] BOWLER'S HISTORICAL PERFORMANCE AGAINST THIS SPECIFIC BATTER:\n")
    cat(sprintf("  • Deliveries Bowled     : %d (Legal: %d | Wides: %d, No-balls: %d)\n", 
                h2h$total_deliveries, legal_bowled, h2h$wides, h2h$noballs))
    cat(sprintf("  • Runs Conceded         : %d runs (Bat runs: %d + Bowler extras: %d)\n", 
                runs_conceded, runs_scored, runs_conceded - runs_scored))
    cat(sprintf("  • Wickets Taken         : %d wickets\n", dismissals))
    cat(sprintf("  • Economy Rate          : %.2f runs per over\n", bowler_econ))
    cat(sprintf("  • Bowling Average       : %s\n", ifelse(is.na(bowler_avg), "N/A (0 wickets)", sprintf("%.2f runs/wicket", bowler_avg))))
    cat(sprintf("  • Bowling Strike Rate   : %s\n", ifelse(is.na(bowler_sr), "N/A (0 wickets)", sprintf("%.1f balls/wicket", bowler_sr))))
    cat(sprintf("  • Dot Ball Dominance    : %d dot balls (%.2f%% of deliveries)\n", dots, dot_pct))
    cat(sprintf("  • Boundaries Conceded   : %d boundaries (%.2f%% boundary concession rate)\n", boundaries, boundary_pct))
    cat(sprintf("  • Bowler Dominance Index: %s\n", bowler_dominance))
    
    # Tactical line/length inference based on dismissal kind
    if (nrow(dism_df) > 0) {
      modes <- dism_df$dismissal_kind
      tactics <- c()
      if (any(modes %in% c("bowled", "lbw"))) tactics <- c(tactics, "Attacking stumps (Seam/In-swing/Skid through gate)")
      if (any(modes %in% c("caught"))) tactics <- c(tactics, "Induced mistimed loft / Edge to keeper/slips or boundary fielder")
      if (any(modes %in% c("stumped"))) tactics <- c(tactics, "Beaten in flight/drift out of crease")
      if (any(modes %in% c("caught and bowled"))) tactics <- c(tactics, "Deception off the pitch / Leading edge return catch")
      cat(sprintf("  • Recurring Vulnerability: %s\n", paste(tactics, collapse = "; ")))
    }
    
    # 3. PHASE BREAKDOWN
    if (nrow(phase_df) > 0) {
      cat("\n[3] PERFORMANCE ACROSS MATCH INNINGS PHASES:\n")
      cat(sprintf("  %-26s | %-6s | %-6s | %-7s | %-8s | %-8s | %-6s\n", 
                  "Innings Phase", "Balls", "Runs", "Wickets", "Str Rate", "Dot %", "4s/6s"))
      cat("  --------------------------------------------------------------------------------\n")
      for (i in seq_len(nrow(phase_df))) {
        r <- phase_df[i, ]
        cat(sprintf("  %-26s | %-6d | %-6d | %-7d | %-8.2f | %-7.1f%% | %d / %d\n",
                    r$phase, r$balls, r$runs, r$wickets, r$strike_rate, r$dot_pct, r$fours, r$sixes))
      }
    }
    
    # 4. CONTEXTUAL & RECENCY DYNAMICS
    cat("\n[4] CONTEXTUAL MATCHUP DYNAMICS & RECENCY COMPARISON:\n")
    if (nrow(era_df) > 0) {
      cat("  • Era Head-to-Head Progression:\n")
      for (i in seq_len(nrow(era_df))) {
        r <- era_df[i, ]
        cat(sprintf("    - %-28s: %d balls, %d runs, %d wkts, SR: %.2f, Dot%%: %.1f%%\n",
                    r$era, r$balls, r$runs, r$wickets, r$strike_rate, r$dot_pct))
      }
    }
    
    # Overall Recent Form in 2023-2024
    cat("  • Independent Recent Form Baseline (2023–2024 IPL Seasons Across All Opponents):\n")
    if (nrow(btr_form) > 0 && btr_form$matches_played > 0) {
      btr_sr_rec <- round((btr_form$runs / btr_form$balls) * 100, 2)
      btr_avg_rec <- ifelse(btr_form$dismissals > 0, round(btr_form$runs / btr_form$dismissals, 2), NA)
      cat(sprintf("    - %s (Recent Form): %d matches, %d runs, %d balls, SR: %.2f, Avg: %s\n",
                  clean_batter, btr_form$matches_played, btr_form$runs, btr_form$balls, btr_sr_rec,
                  ifelse(is.na(btr_avg_rec), "Undefeated", sprintf("%.2f", btr_avg_rec))))
    }
    if (nrow(bwl_form) > 0 && bwl_form$matches_played > 0) {
      bwl_econ_rec <- round((bwl_form$runs_conceded / bwl_form$legal_balls) * 6, 2)
      bwl_sr_rec <- ifelse(bwl_form$wickets > 0, round(bwl_form$legal_balls / bwl_form$wickets, 1), NA)
      cat(sprintf("    - %s (Recent Form): %d matches, %d wkts, %d balls, Econ: %.2f, SR: %s\n",
                  clean_bowler, bwl_form$matches_played, bwl_form$wickets, bwl_form$legal_balls, bwl_econ_rec,
                  ifelse(is.na(bwl_sr_rec), "N/A", sprintf("%.1f", bwl_sr_rec))))
    }
    
    # Top Venues
    if (nrow(venues_df) > 0) {
      cat("  • Top Venues for this Head-to-Head Encounter:\n")
      for (i in seq_len(min(3, nrow(venues_df)))) {
        r <- venues_df[i, ]
        cat(sprintf("    - %-32s: %d balls, %d runs, %d wkts (SR: %.2f)\n",
                    r$venue, r$balls, r$runs, r$wickets, r$strike_rate))
      }
    }
    
    # Strategic Weighting Recommendation
    cat("\n[5] STRATEGIC DECISION-MAKING & WEIGHTING ADVISORY:\n")
    if (balls_faced >= 45) {
      cat("  > RECOMMENDATION: HIGH CONFIDENCE MATCHUP SPECIFICITY.\n")
      cat("    The historical sample size is statistically robust. Prior head-to-head tactical patterns\n")
      cat("    should be prioritized over general career form when making bowling changes or field settings.\n")
    } else if (balls_faced >= 20) {
      cat("  > RECOMMENDATION: MODERATE CONFIDENCE.\n")
      cat("    Sufficient sample exists to confirm distinct tactical patterns, but weigh head-to-head\n")
      cat("    data equally with current tournament form (2023-2024 season momentum).\n")
    } else {
      cat("  > RECOMMENDATION: HIGH VARIANCE SAMPLE.\n")
      cat("    Small head-to-head sample size (< 20 balls). Give greater statistical weight to recent\n")
      cat("    form, pitch conditions, and broader bowling-type vs batting-handedness tendencies.\n")
    }
    cat("========================================================================================\n\n")
  }
  
  invisible(list(
    batter = clean_batter,
    bowler = clean_bowler,
    sample_size_tier = sample_size_tier,
    balls_faced = balls_faced,
    runs_scored = runs_scored,
    dismissals = dismissals,
    batting_strike_rate = bat_sr,
    batting_average = bat_avg,
    dot_ball_percentage = dot_pct,
    fours = fours,
    sixes = sixes,
    boundaries = boundaries,
    rotations = rotations,
    bowler_economy = bowler_econ,
    bowler_average = bowler_avg,
    bowler_strike_rate = bowler_sr,
    batter_tendency = batter_tendency,
    bowler_dominance = bowler_dominance,
    phases = phase_df,
    eras = era_df,
    venues = venues_df,
    batter_recent_form = btr_form,
    bowler_recent_form = bwl_form
  ))
}

# ------------------------------------------------------------------------------
# 3. Dynamic Live Matchup Tracker
# ------------------------------------------------------------------------------
# Simulates or tracks when the striker rotates or the bowling captain makes a change
track_dynamic_matchup <- function(batter, bowler, venue = NULL, over = NULL, db_path = "database/ipl_database.sqlite") {
  cat(sprintf("\n>>> [LIVE MATCH EVENT DETECTED: Striker / Bowler Rotation]\n"))
  cat(sprintf(">>> Dynamic State: Striker = %s | Bowler into Attack = %s\n", batter, bowler))
  analyze_matchup(batter_name = batter, 
                  bowler_name = bowler, 
                  venue_name = venue, 
                  current_over = over, 
                  db_path = db_path, 
                  verbose = TRUE)
}

# ------------------------------------------------------------------------------
# 4. CLI Execution Driver
# ------------------------------------------------------------------------------
if (!interactive() && sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  
  if (length(args) >= 2) {
    btr_arg <- args[1]
    bwl_arg <- args[2]
    ven_arg <- if (length(args) >= 3) args[3] else NULL
    ovr_arg <- if (length(args) >= 4) as.numeric(args[4]) else NULL
    
    analyze_matchup(btr_arg, bwl_arg, venue_name = ven_arg, current_over = ovr_arg)
  } else {
    # Default Demonstration Mode: Run 3 iconic matchups
    cat("========================================================================================\n")
    cat("        AUTOMATED DEMONSTRATION OF CLASSIC IPL BATTER-BOWLER MATCHUPS\n")
    cat("========================================================================================\n")
    
    cat("\n>>> DEMO 1: Rohit Sharma vs. Sunil Narine (Legendary Middle-Overs Spin Dominance)\n")
    analyze_matchup("Rohit Sharma", "Sunil Narine")
    
    cat("\n>>> DEMO 2: Virat Kohli vs. Jasprit Bumrah (Master Batsman vs. Premier Fast Bowler)\n")
    analyze_matchup("Virat Kohli", "Jasprit Bumrah", venue_name = "Wankhede Stadium", current_over = 18)
    
    cat("\n>>> DEMO 3: MS Dhoni vs. Sunil Narine (Master Tactician Ultra-Defense vs. Mystery Spin)\n")
    analyze_matchup("MS Dhoni", "Sunil Narine")
  }
}
