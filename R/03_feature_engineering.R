# ==============================================================================
# File: 03_feature_engineering.R
# Project: A Comparative Study of ML Models for Explainable IPL Match Outcome Prediction
# Description: Rigorous pre-match feature engineering with strict zero target leakage
# ==============================================================================

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(tidyr)
})

cat("====================================================================\n")
cat("                STEP 3: PRE-MATCH FEATURE ENGINEERING               \n")
cat("====================================================================\n\n")

db_path <- "database/ipl_database.sqlite"
con <- dbConnect(SQLite(), db_path)

cat("Fetching matches and deliveries data from SQLite database...\n")
matches <- dbGetQuery(con, "
  SELECT id, season, city, date, match_type, venue, team1, team2, toss_winner, toss_decision, winner, result
  FROM matches
  WHERE winner IS NOT NULL AND winner != '' AND winner != 'NA'
  ORDER BY date ASC, id ASC;
")

first_inn_runs <- dbGetQuery(con, "
  SELECT match_id, SUM(total_runs) AS first_innings_runs
  FROM deliveries
  WHERE inning = 1
  GROUP BY match_id;
")

cat(sprintf("Retrieved %d valid matches and %d match first-innings scores.\n\n", nrow(matches), nrow(first_inn_runs)))

# Join 1st innings runs to matches
matches <- matches %>% 
  left_join(first_inn_runs, by = c("id" = "match_id"))

# Global default 1st innings score if unavailable
global_avg_1st_inn <- mean(matches$first_innings_runs, na.rm = TRUE)

n_matches <- nrow(matches)
cat(sprintf("Computing pre-match chronological features for %d matches...\n", n_matches))

# Containers for engineered features
team1_win_pct <- numeric(n_matches)
team2_win_pct <- numeric(n_matches)
win_pct_diff <- numeric(n_matches)

team1_recent_form <- numeric(n_matches)
team2_recent_form <- numeric(n_matches)
recent_form_diff <- numeric(n_matches)

team1_h2h_win_pct <- numeric(n_matches)
team2_h2h_win_pct <- numeric(n_matches)
h2h_diff <- numeric(n_matches)

team1_venue_win_pct <- numeric(n_matches)
team2_venue_win_pct <- numeric(n_matches)
venue_performance_diff <- numeric(n_matches)

venue_average_score <- numeric(n_matches)
venue_toss_win_pct <- numeric(n_matches)

toss_winner_is_team1 <- numeric(n_matches)
toss_decision_bat <- numeric(n_matches)
is_playoff <- numeric(n_matches)
team1_won <- integer(n_matches)

# Chronological Feature Calculation (Loop strictly over prior matches i < m to eliminate data leakage)
for (i in 1:n_matches) {
  cur_team1 <- matches$team1[i]
  cur_team2 <- matches$team2[i]
  cur_venue <- matches$venue[i]
  cur_toss_win <- matches$toss_winner[i]
  cur_toss_dec <- matches$toss_decision[i]
  cur_winner <- matches$winner[i]
  cur_match_type <- matches$match_type[i]
  
  # Target variable
  team1_won[i] <- ifelse(cur_winner == cur_team1, 1, 0)
  
  # Toss and Match Context
  toss_winner_is_team1[i] <- ifelse(cur_toss_win == cur_team1, 1, 0)
  toss_decision_bat[i] <- ifelse(cur_toss_dec == "bat", 1, 0)
  is_playoff[i] <- ifelse(tolower(cur_match_type) == "league", 0, 1)
  
  if (i == 1) {
    # Prior to Match 1 in IPL history, use neutral priors (Laplace smoothed)
    team1_win_pct[i] <- 0.50
    team2_win_pct[i] <- 0.50
    win_pct_diff[i] <- 0.00
    
    team1_recent_form[i] <- 0.50
    team2_recent_form[i] <- 0.50
    recent_form_diff[i] <- 0.00
    
    team1_h2h_win_pct[i] <- 0.50
    team2_h2h_win_pct[i] <- 0.50
    h2h_diff[i] <- 0.00
    
    team1_venue_win_pct[i] <- 0.50
    team2_venue_win_pct[i] <- 0.50
    venue_performance_diff[i] <- 0.00
    
    venue_average_score[i] <- round(global_avg_1st_inn, 2)
    venue_toss_win_pct[i] <- 0.50
  } else {
    prior <- matches[1:(i - 1), ]
    
    # 1. Overall Team Cumulative Win Percentage (Laplace Smoothed: (wins + 1)/(matches + 2))
    t1_prior_matches <- prior %>% filter(team1 == cur_team1 | team2 == cur_team1)
    t1_prior_wins <- sum(t1_prior_matches$winner == cur_team1)
    team1_win_pct[i] <- (t1_prior_wins + 1) / (nrow(t1_prior_matches) + 2)
    
    t2_prior_matches <- prior %>% filter(team1 == cur_team2 | team2 == cur_team2)
    t2_prior_wins <- sum(t2_prior_matches$winner == cur_team2)
    team2_win_pct[i] <- (t2_prior_wins + 1) / (nrow(t2_prior_matches) + 2)
    
    win_pct_diff[i] <- team1_win_pct[i] - team2_win_pct[i]
    
    # 2. Recent Form: Win % over last 5 matches for each team
    if (nrow(t1_prior_matches) > 0) {
      t1_last5 <- tail(t1_prior_matches, 5)
      team1_recent_form[i] <- sum(t1_last5$winner == cur_team1) / nrow(t1_last5)
    } else {
      team1_recent_form[i] <- 0.50
    }
    
    if (nrow(t2_prior_matches) > 0) {
      t2_last5 <- tail(t2_prior_matches, 5)
      team2_recent_form[i] <- sum(t2_last5$winner == cur_team2) / nrow(t2_last5)
    } else {
      team2_recent_form[i] <- 0.50
    }
    
    recent_form_diff[i] <- team1_recent_form[i] - team2_recent_form[i]
    
    # 3. Head-to-Head Win Percentage (prior to this encounter)
    h2h_prior <- prior %>% 
      filter((team1 == cur_team1 & team2 == cur_team2) | (team1 == cur_team2 & team2 == cur_team1))
    
    if (nrow(h2h_prior) > 0) {
      t1_h2h_wins <- sum(h2h_prior$winner == cur_team1)
      team1_h2h_win_pct[i] <- (t1_h2h_wins + 1) / (nrow(h2h_prior) + 2)
      team2_h2h_win_pct[i] <- 1 - team1_h2h_win_pct[i]
    } else {
      team1_h2h_win_pct[i] <- 0.50
      team2_h2h_win_pct[i] <- 0.50
    }
    h2h_diff[i] <- team1_h2h_win_pct[i] - team2_h2h_win_pct[i]
    
    # 4. Venue-Specific Win Percentage for Each Team
    t1_venue_prior <- prior %>% 
      filter(venue == cur_venue & (team1 == cur_team1 | team2 == cur_team1))
    t2_venue_prior <- prior %>% 
      filter(venue == cur_venue & (team1 == cur_team2 | team2 == cur_team2))
    
    t1_venue_wins <- sum(t1_venue_prior$winner == cur_team1)
    t2_venue_wins <- sum(t2_venue_prior$winner == cur_team2)
    
    team1_venue_win_pct[i] <- (t1_venue_wins + 1) / (nrow(t1_venue_prior) + 2)
    team2_venue_win_pct[i] <- (t2_venue_wins + 1) / (nrow(t2_venue_prior) + 2)
    venue_performance_diff[i] <- team1_venue_win_pct[i] - team2_venue_win_pct[i]
    
    # 5. Venue Historical Average First Innings Runs & Toss Win Rate
    venue_prior <- prior %>% filter(venue == cur_venue)
    if (nrow(venue_prior) > 0) {
      v_scores <- na.omit(venue_prior$first_innings_runs)
      venue_average_score[i] <- if (length(v_scores) > 0) round(mean(v_scores), 2) else round(global_avg_1st_inn, 2)
      v_toss_wins <- sum(venue_prior$toss_winner == venue_prior$winner)
      venue_toss_win_pct[i] <- (v_toss_wins + 1) / (nrow(venue_prior) + 2)
    } else {
      venue_average_score[i] <- round(global_avg_1st_inn, 2)
      venue_toss_win_pct[i] <- 0.50
    }
  }
}

features_df <- data.frame(
  id = matches$id,
  season = matches$season,
  date = matches$date,
  team1 = matches$team1,
  team2 = matches$team2,
  venue = matches$venue,
  team1_win_pct = round(team1_win_pct, 4),
  team2_win_pct = round(team2_win_pct, 4),
  win_pct_diff = round(win_pct_diff, 4),
  team1_recent_form = round(team1_recent_form, 4),
  team2_recent_form = round(team2_recent_form, 4),
  recent_form_diff = round(recent_form_diff, 4),
  team1_h2h_win_pct = round(team1_h2h_win_pct, 4),
  team2_h2h_win_pct = round(team2_h2h_win_pct, 4),
  h2h_diff = round(h2h_diff, 4),
  team1_venue_win_pct = round(team1_venue_win_pct, 4),
  team2_venue_win_pct = round(team2_venue_win_pct, 4),
  venue_performance_diff = round(venue_performance_diff, 4),
  venue_average_score = round(venue_average_score, 2),
  venue_toss_win_pct = round(venue_toss_win_pct, 4),
  toss_winner_is_team1 = toss_winner_is_team1,
  toss_decision_bat = toss_decision_bat,
  is_playoff = is_playoff,
  team1_won = team1_won,
  stringsAsFactors = FALSE
)

cat("Sample engineered features (first 5 matches):\n")
print(head(features_df[, c("id", "season", "team1", "team2", "win_pct_diff", "recent_form_diff", "h2h_diff", "toss_winner_is_team1", "team1_won")], 5))

# Write table to SQLite
cat("\nWriting 'model_features' table to SQLite...\n")
dbWriteTable(con, "model_features", features_df, overwrite = TRUE)
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_features_id ON model_features(id);")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_features_season ON model_features(season);")

dbDisconnect(con)

# Save CSV copy
write.csv(features_df, "data/ipl_features.csv", row.names = FALSE)

cat("\nFeature engineering successfully completed. Saved to SQLite table 'model_features' and 'data/ipl_features.csv'.\n")
cat("====================================================================\n\n")
