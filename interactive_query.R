# ==============================================================================
# File: interactive_query.R
# Project: A Comparative Study of ML Models for Explainable IPL Match Outcome Prediction
# Description: Interactive query tool for probabilities, team comparisons, and models
# ==============================================================================

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
})

db_path <- "database/ipl_database.sqlite"

# Helper to get DB connection
get_db <- function() {
  dbConnect(SQLite(), db_path)
}

# ------------------------------------------------------------------------------
# 1. Calculate Team Win Probability at Venue
# ------------------------------------------------------------------------------
get_team_venue_probability <- function(team_name, venue_name = NULL) {
  con <- get_db()
  
  if (is.null(venue_name)) {
    q <- sprintf("
      SELECT 
        COUNT(*) AS total_matches,
        SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) AS wins
      FROM matches
      WHERE (team1 = '%s' OR team2 = '%s')
        AND winner IS NOT NULL AND winner != '' AND winner != 'NA';
    ", team_name, team_name, team_name)
    context_desc <- sprintf("%s Overall Record", team_name)
  } else {
    q <- sprintf("
      SELECT 
        COUNT(*) AS total_matches,
        SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) AS wins
      FROM matches
      WHERE (team1 = '%s' OR team2 = '%s')
        AND venue LIKE '%%%s%%'
        AND winner IS NOT NULL AND winner != '' AND winner != 'NA';
    ", team_name, team_name, team_name, venue_name)
    context_desc <- sprintf("%s at %s", team_name, venue_name)
  }
  
  res <- dbGetQuery(con, q)
  dbDisconnect(con)
  
  matches_played <- res$total_matches
  wins <- ifelse(is.na(res$wins), 0, res$wins)
  prob <- ifelse(matches_played > 0, wins / matches_played, 0)
  pct  <- round(prob * 100, 2)
  
  cat("\n====================================================================\n")
  cat(sprintf("QUERY RESULT: %s\n", toupper(context_desc)))
  cat("====================================================================\n")
  cat(sprintf("Team            : %s\n", team_name))
  if (!is.null(venue_name)) cat(sprintf("Venue Match     : %s\n", venue_name))
  cat(sprintf("Matches Played  : %d\n", matches_played))
  cat(sprintf("Wins            : %d\n", wins))
  cat(sprintf("Win Probability : %.4f\n", prob))
  cat(sprintf("Win Percentage  : %.2f%%\n", pct))
  cat("====================================================================\n\n")
  
  invisible(list(matches = matches_played, wins = wins, probability = prob, percentage = pct))
}

# ------------------------------------------------------------------------------
# 2. Compare Two Teams (Head-to-Head and Overall)
# ------------------------------------------------------------------------------
compare_teams <- function(team_a, team_b) {
  con <- get_db()
  
  # Overall stats
  q_overall <- sprintf("
    SELECT 
      winner AS Team,
      COUNT(*) AS Total_Wins
    FROM matches
    WHERE winner IN ('%s', '%s')
    GROUP BY winner;
  ", team_a, team_b)
  overall_res <- dbGetQuery(con, q_overall)
  
  # Total matches played by each
  q_t1_m <- sprintf("SELECT COUNT(*) AS total FROM matches WHERE (team1 = '%s' OR team2 = '%s') AND winner IS NOT NULL AND winner != '';", team_a, team_a)
  t1_matches <- dbGetQuery(con, q_t1_m)$total
  
  q_t2_m <- sprintf("SELECT COUNT(*) AS total FROM matches WHERE (team1 = '%s' OR team2 = '%s') AND winner IS NOT NULL AND winner != '';", team_b, team_b)
  t2_matches <- dbGetQuery(con, q_t2_m)$total
  
  t1_wins <- ifelse(length(overall_res$Total_Wins[overall_res$Team == team_a]) > 0, overall_res$Total_Wins[overall_res$Team == team_a], 0)
  t2_wins <- ifelse(length(overall_res$Total_Wins[overall_res$Team == team_b]) > 0, overall_res$Total_Wins[overall_res$Team == team_b], 0)
  
  # Head to head matches
  q_h2h <- sprintf("
    SELECT 
      COUNT(*) AS h2h_matches,
      SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) AS t1_h2h_wins,
      SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) AS t2_h2h_wins
    FROM matches
    WHERE ((team1 = '%s' AND team2 = '%s') OR (team1 = '%s' AND team2 = '%s'))
      AND winner IS NOT NULL AND winner != '';
  ", team_a, team_b, team_a, team_b, team_b, team_a)
  h2h_res <- dbGetQuery(con, q_h2h)
  
  # Toss Win conversion for both
  q_toss_t1 <- sprintf("
    SELECT 
      COUNT(*) AS toss_wins,
      SUM(CASE WHEN toss_winner = winner THEN 1 ELSE 0 END) AS toss_and_match_wins
    FROM matches
    WHERE toss_winner = '%s' AND winner IS NOT NULL AND winner != '';
  ", team_a)
  toss_t1 <- dbGetQuery(con, q_toss_t1)
  
  q_toss_t2 <- sprintf("
    SELECT 
      COUNT(*) AS toss_wins,
      SUM(CASE WHEN toss_winner = winner THEN 1 ELSE 0 END) AS toss_and_match_wins
    FROM matches
    WHERE toss_winner = '%s' AND winner IS NOT NULL AND winner != '';
  ", team_b)
  toss_t2 <- dbGetQuery(con, q_toss_t2)
  
  dbDisconnect(con)
  
  cat("\n====================================================================\n")
  cat(sprintf("HEAD-TO-HEAD & COMPARATIVE PROFILE: %s vs %s\n", toupper(team_a), toupper(team_b)))
  cat("====================================================================\n")
  cat(sprintf("%-30s | %-18s | %-18s\n", "Metric", team_a, team_b))
  cat("--------------------------------------------------------------------\n")
  cat(sprintf("%-30s | %-18d | %-18d\n", "Total Matches Played", t1_matches, t2_matches))
  cat(sprintf("%-30s | %-18d | %-18d\n", "Overall IPL Wins", t1_wins, t2_wins))
  cat(sprintf("%-30s | %-17.2f%% | %-17.2f%%\n", "Overall Win Percentage", (t1_wins / t1_matches) * 100, (t2_wins / t2_matches) * 100))
  cat(sprintf("%-30s | %-18d | %-18d\n", "Head-to-Head Wins", h2h_res$t1_h2h_wins, h2h_res$t2_h2h_wins))
  cat(sprintf("%-30s | %-17.2f%% | %-17.2f%%\n", "Head-to-Head Win %", (h2h_res$t1_h2h_wins / h2h_res$h2h_matches) * 100, (h2h_res$t2_h2h_wins / h2h_res$h2h_matches) * 100))
  cat(sprintf("%-30s | %-17.2f%% | %-17.2f%%\n", "Toss-Win Match-Win %", (toss_t1$toss_and_match_wins / toss_t1$toss_wins) * 100, (toss_t2$toss_and_match_wins / toss_t2$toss_wins) * 100))
  cat(sprintf("Total Head-to-Head Matches: %d\n", h2h_res$h2h_matches))
  cat("====================================================================\n\n")
}

# ------------------------------------------------------------------------------
# 3. Model Comparison Table Viewer
# ------------------------------------------------------------------------------
compare_models <- function(models_to_filter = NULL) {
  df <- read.csv("results/model_comparison.csv", stringsAsFactors = FALSE)
  if (!is.null(models_to_filter)) {
    df <- df %>% filter(Model %in% models_to_filter)
  }
  
  cat("\n====================================================================\n")
  cat("                     MODEL COMPARISON METRICS                       \n")
  cat("====================================================================\n")
  print(df[, c("Model", "Accuracy", "Precision", "Recall", "F1", "ROC_AUC")])
  cat("====================================================================\n\n")
}

# Quick demonstration if run from command line
if (!interactive()) {
  cat("Demonstration 1: Win probability of Mumbai Indians at Wankhede Stadium\n")
  get_team_venue_probability("Mumbai Indians", "Wankhede")
  
  cat("Demonstration 2: Head-to-Head comparison of Mumbai Indians vs Chennai Super Kings\n")
  compare_teams("Mumbai Indians", "Chennai Super Kings")
  
  cat("Demonstration 3: Comparison of Random Forest, SVM, and Logistic Regression\n")
  compare_models(c("Random Forest", "SVM", "Logistic Regression"))
}
