# ==============================================================================
# File: api/plumber.R
# Project: Explainable IPL Match Outcome Prediction
# Description: Production Plumber REST API serving pre-match models and statistics
# ==============================================================================

suppressPackageStartupMessages({
  library(plumber)
  library(DBI)
  library(RSQLite)
  library(jsonlite)
  library(rpart)
  library(class)
  library(nnet)
  if (requireNamespace("randomForest", quietly = TRUE)) library(randomForest)
  if (requireNamespace("e1071", quietly = TRUE)) library(e1071)
  if (requireNamespace("gbm", quietly = TRUE)) library(gbm)
})

# ------------------------------------------------------------------------------
# 1. Global Setup: Load Models, Features, and Database
# ------------------------------------------------------------------------------
get_project_file <- function(rel_path) {
  candidates <- c(
    rel_path,
    file.path("..", rel_path),
    file.path(getwd(), rel_path),
    file.path(getwd(), "..", rel_path)
  )
  for (cand in candidates) {
    if (file.exists(cand)) return(normalizePath(cand, winslash = "/"))
  }
  rel_path
}

db_path <- get_project_file("database/ipl_database.sqlite")
bundle_path <- get_project_file("results/models_and_predictions.rds")
metrics_path <- get_project_file("results/model_comparison.csv")

cat("Resolved bundle path:", bundle_path, "\n")
cat("Resolved database path:", db_path, "\n")
bundle <- readRDS(bundle_path)
models_list <- bundle$models
sel_feats <- bundle$selected_features

# Precompute scaling vectors from training data
mean_vec <- colMeans(bundle$train_data[, sel_feats])
sd_vec <- apply(bundle$train_data[, sel_feats], 2, sd)
sd_vec[sd_vec == 0] <- 1

# Load benchmark metrics table
model_metrics <- if (file.exists(metrics_path)) {
  read.csv(metrics_path, stringsAsFactors = FALSE)
} else {
  data.frame()
}

# Franchise Metadata
team_metadata <- list(
  "Mumbai Indians" = list(short = "MI", primary = "#004BA0", secondary = "#D1AB3E", titles = 5),
  "Chennai Super Kings" = list(short = "CSK", primary = "#FDB913", secondary = "#0081E8", titles = 5),
  "Kolkata Knight Riders" = list(short = "KKR", primary = "#3A225D", secondary = "#F4C430", titles = 3),
  "Royal Challengers Bengaluru" = list(short = "RCB", primary = "#EC1C24", secondary = "#000000", titles = 0),
  "Sunrisers Hyderabad" = list(short = "SRH", primary = "#F7A721", secondary = "#000000", titles = 2),
  "Rajasthan Royals" = list(short = "RR", primary = "#EA1A85", secondary = "#254AA5", titles = 1),
  "Delhi Capitals" = list(short = "DC", primary = "#00008B", secondary = "#D71920", titles = 0),
  "Punjab Kings" = list(short = "PBKS", primary = "#ED1B24", secondary = "#DCDDDF", titles = 0),
  "Gujarat Titans" = list(short = "GT", primary = "#1B2133", secondary = "#E0B0FF", titles = 1),
  "Lucknow Super Giants" = list(short = "LSG", primary = "#A2D2FF", secondary = "#FF686B", titles = 0),
  "Rising Pune Supergiant" = list(short = "RPS", primary = "#D11D4E", secondary = "#243355", titles = 0),
  "Gujarat Lions" = list(short = "GL", primary = "#E34E17", secondary = "#1C4E80", titles = 0),
  "Kochi Tuskers Kerala" = list(short = "KTK", primary = "#6F2282", secondary = "#E37424", titles = 0),
  "Pune Warriors" = list(short = "PWI", primary = "#2F9EBD", secondary = "#000000", titles = 0)
)

# Helper for SQLite connection
get_con <- function() {
  dbConnect(SQLite(), db_path)
}

#* @apiTitle IPL Match Outcome Prediction API
#* @apiDescription Strict Zero-Target-Leakage Machine Learning Prediction Engine for IPL Matches
#* @apiVersion 1.0.0

# ------------------------------------------------------------------------------
# 2. CORS Filter for Frontend Communication
# ------------------------------------------------------------------------------
#* @filter cors
cors <- function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept, Origin, X-Requested-With")
  
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(list(status = "ok"))
  }
  
  plumber::forward()
}

# ------------------------------------------------------------------------------
# 3. Health & Status
# ------------------------------------------------------------------------------
#* Health check endpoint
#* @get /api/health
function() {
  con <- get_con()
  m_count <- dbGetQuery(con, "SELECT COUNT(*) as n FROM matches;")$n
  dbDisconnect(con)
  
  list(
    status = "ok",
    database = list(
      connected = TRUE,
      total_matches = m_count
    ),
    loaded_models_count = length(models_list),
    features_count = length(sel_feats),
    timestamp = as.character(Sys.time())
  )
}

# ------------------------------------------------------------------------------
# 4. Model Benchmark Leaderboard
# ------------------------------------------------------------------------------
#* Return benchmarked evaluation metrics for all 12 models
#* @get /api/models
function() {
  list(
    status = "success",
    count = nrow(model_metrics),
    benchmark = model_metrics
  )
}

# ------------------------------------------------------------------------------
# 5. Teams Endpoint
# ------------------------------------------------------------------------------
#* Return all IPL franchises with historical wins, win percentages, and branding
#* @get /api/teams
function() {
  con <- get_con()
  
  # Top teams based on participation
  teams_df <- dbGetQuery(con, "
    SELECT 
      team,
      COUNT(*) AS total_matches,
      SUM(is_win) AS total_wins
    FROM (
      SELECT team1 AS team, CASE WHEN winner = team1 THEN 1 ELSE 0 END AS is_win FROM matches WHERE winner IS NOT NULL AND winner != ''
      UNION ALL
      SELECT team2 AS team, CASE WHEN winner = team2 THEN 1 ELSE 0 END AS is_win FROM matches WHERE winner IS NOT NULL AND winner != ''
    )
    GROUP BY team
    HAVING total_matches >= 14
    ORDER BY total_wins DESC;
  ")
  
  dbDisconnect(con)
  
  teams_list <- list()
  for (i in 1:nrow(teams_df)) {
    t_name <- teams_df$team[i]
    meta <- team_metadata[[t_name]]
    if (is.null(meta)) {
      meta <- list(short = substr(t_name, 1, 3), primary = "#1E293B", secondary = "#64748B", titles = 0)
    }
    
    m_played <- as.integer(teams_df$total_matches[i])
    m_wins <- as.integer(teams_df$total_wins[i])
    w_pct <- round((m_wins / m_played) * 100, 2)
    
    teams_list[[length(teams_list) + 1]] <- list(
      name = t_name,
      short_name = meta$short,
      primary_color = meta$primary,
      secondary_color = meta$secondary,
      titles = meta$titles,
      matches_played = m_played,
      wins = m_wins,
      win_percentage = w_pct
    )
  }
  
  list(
    status = "success",
    count = length(teams_list),
    teams = teams_list
  )
}

# ------------------------------------------------------------------------------
# 6. Venues Endpoint
# ------------------------------------------------------------------------------
#* Return all official IPL stadiums with historical scoring and toss records
#* @get /api/venues
function() {
  con <- get_con()
  
  venues_df <- dbGetQuery(con, "
    SELECT 
      m.venue,
      m.city,
      COUNT(DISTINCT m.id) AS total_matches,
      ROUND(AVG(f.first_innings_runs), 1) AS avg_first_innings_score,
      ROUND(AVG(CASE WHEN m.toss_winner = m.winner THEN 1.0 ELSE 0.0 END) * 100, 2) AS toss_win_match_win_pct,
      ROUND(AVG(CASE WHEN (m.toss_decision = 'bat' AND m.toss_winner = m.winner) OR (m.toss_decision = 'field' AND m.toss_winner != m.winner) THEN 1.0 ELSE 0.0 END) * 100, 2) AS bat_first_win_pct
    FROM matches m
    LEFT JOIN (
      SELECT match_id, SUM(total_runs) AS first_innings_runs
      FROM deliveries
      WHERE inning = 1
      GROUP BY match_id
    ) f ON m.id = f.match_id
    WHERE m.winner IS NOT NULL AND m.winner != '' AND m.venue IS NOT NULL AND m.venue != ''
    GROUP BY m.venue
    HAVING total_matches >= 5
    ORDER BY total_matches DESC;
  ")
  
  dbDisconnect(con)
  
  venues_list <- list()
  for (i in 1:nrow(venues_df)) {
    venues_list[[length(venues_list) + 1]] <- list(
      venue = venues_df$venue[i],
      city = ifelse(is.na(venues_df$city[i]) || venues_df$city[i] == "", "India", venues_df$city[i]),
      matches = as.integer(venues_df$total_matches[i]),
      avg_score = ifelse(is.na(venues_df$avg_first_innings_score[i]), 165.7, as.numeric(venues_df$avg_first_innings_score[i])),
      toss_win_pct = ifelse(is.na(venues_df$toss_win_match_win_pct[i]), 50.0, as.numeric(venues_df$toss_win_match_win_pct[i])),
      bat_first_win_pct = ifelse(is.na(venues_df$bat_first_win_pct[i]), 50.0, as.numeric(venues_df$bat_first_win_pct[i]))
    )
  }
  
  list(
    status = "success",
    count = length(venues_list),
    venues = venues_list
  )
}

# ------------------------------------------------------------------------------
# 7. Head-to-Head & Team Comparison Endpoint
# ------------------------------------------------------------------------------
#* Return head-to-head match records and recent 5-match form
#* @get /api/h2h
#* @param team1:character First team name
#* @param team2:character Second team name
function(res, team1 = "", team2 = "") {
  if (team1 == "" || team2 == "") {
    res$status <- 400
    return(list(status = "error", message = "Both 'team1' and 'team2' parameters are required."))
  }
  
  if (team1 == team2) {
    res$status <- 400
    return(list(status = "error", message = "'team1' and 'team2' must be distinct teams."))
  }
  
  con <- get_con()
  
  # Head-to-Head matches
  q_h2h <- sprintf("
    SELECT 
      id, season, date, venue, winner, result, result_margin
    FROM matches
    WHERE ((team1 = '%s' AND team2 = '%s') OR (team1 = '%s' AND team2 = '%s'))
      AND winner IS NOT NULL AND winner != ''
    ORDER BY date DESC;
  ", team1, team2, team2, team1)
  
  h2h_matches <- dbGetQuery(con, q_h2h)
  
  total_h2h <- nrow(h2h_matches)
  t1_h2h_wins <- sum(h2h_matches$winner == team1)
  t2_h2h_wins <- sum(h2h_matches$winner == team2)
  
  # Last 5 matches for Team 1
  q_t1_form <- sprintf("
    SELECT winner, date FROM matches 
    WHERE (team1 = '%s' OR team2 = '%s') AND winner IS NOT NULL AND winner != ''
    ORDER BY date DESC LIMIT 5;
  ", team1, team1)
  t1_form_df <- dbGetQuery(con, q_t1_form)
  t1_recent_results <- ifelse(t1_form_df$winner == team1, "W", "L")
  
  # Last 5 matches for Team 2
  q_t2_form <- sprintf("
    SELECT winner, date FROM matches 
    WHERE (team1 = '%s' OR team2 = '%s') AND winner IS NOT NULL AND winner != ''
    ORDER BY date DESC LIMIT 5;
  ", team2, team2)
  t2_form_df <- dbGetQuery(con, q_t2_form)
  t2_recent_results <- ifelse(t2_form_df$winner == team2, "W", "L")
  
  dbDisconnect(con)
  
  # Recent encounters list
  recent_encounters <- list()
  if (total_h2h > 0) {
    max_recs <- min(5, total_h2h)
    for (i in 1:max_recs) {
      margin_txt <- if (!is.na(h2h_matches$result_margin[i])) {
        sprintf("%s %s", h2h_matches$result_margin[i], h2h_matches$result[i])
      } else {
        "Super Over / Normal"
      }
      recent_encounters[[i]] <- list(
        date = h2h_matches$date[i],
        season = h2h_matches$season[i],
        venue = h2h_matches$venue[i],
        winner = h2h_matches$winner[i],
        margin = margin_txt
      )
    }
  }
  
  list(
    status = "success",
    comparison = list(
      team1 = team1,
      team2 = team2,
      total_h2h_matches = total_h2h,
      team1_wins = t1_h2h_wins,
      team2_wins = t2_h2h_wins,
      team1_h2h_win_pct = if (total_h2h > 0) round((t1_h2h_wins / total_h2h) * 100, 2) else 50.0,
      team2_h2h_win_pct = if (total_h2h > 0) round((t2_h2h_wins / total_h2h) * 100, 2) else 50.0,
      team1_recent_form = t1_recent_results,
      team2_recent_form = t2_recent_results,
      recent_encounters = recent_encounters
    )
  )
}

# ------------------------------------------------------------------------------
# 8. Core Prediction Endpoint
# ------------------------------------------------------------------------------
#* Calculate features and predict match outcome probabilities
#* @post /api/predict
#* @serializer json
function(req, res, team1 = "", team2 = "", venue = "", toss_winner = "", toss_decision = "", is_playoff = 0, model = "Consensus") {
  # Support JSON body via Plumber args, req$body, or raw postBody
  body_data <- list()
  if (!is.null(req$body) && is.list(req$body)) {
    body_data <- req$body
  } else if (!is.null(req$postBody) && length(req$postBody) > 0) {
    parsed <- tryCatch({
      txt <- if (is.raw(req$postBody)) rawToChar(req$postBody) else as.character(req$postBody)
      jsonlite::fromJSON(txt)
    }, error = function(e) NULL)
    if (!is.null(parsed) && is.list(parsed)) body_data <- parsed
  }
  
  val_or_default <- function(direct_val, body_key, def_val = "") {
    if (!missing(direct_val) && !is.null(direct_val) && direct_val != "") return(direct_val)
    if (!is.null(body_data[[body_key]]) && body_data[[body_key]] != "") return(body_data[[body_key]])
    def_val
  }
  
  t1 <- trimws(as.character(val_or_default(team1, "team1")))
  t2 <- trimws(as.character(val_or_default(team2, "team2")))
  ven <- trimws(as.character(val_or_default(venue, "venue")))
  toss_win <- trimws(as.character(val_or_default(toss_winner, "toss_winner")))
  toss_dec <- tolower(trimws(as.character(val_or_default(toss_decision, "toss_decision"))))
  raw_playoff <- val_or_default(is_playoff, "is_playoff", 0)
  is_ko <- as.integer(ifelse(raw_playoff == 1 || raw_playoff == "1" || raw_playoff == TRUE, 1, 0))
  requested_model <- trimws(as.character(val_or_default(model, "model", "Consensus")))
  
  # Validation
  if (t1 == "" || t2 == "") {
    res$status <- 400
    return(list(status = "error", message = "Both 'team1' and 'team2' are required."))
  }
  if (t1 == t2) {
    res$status <- 400
    return(list(status = "error", message = "'team1' and 'team2' cannot be the same team."))
  }
  if (ven == "") {
    res$status <- 400
    return(list(status = "error", message = "'venue' is required."))
  }
  if (toss_win != t1 && toss_win != t2) {
    res$status <- 400
    return(list(status = "error", message = sprintf("'toss_winner' must be either '%s' or '%s'.", t1, t2)))
  }
  if (toss_dec != "bat" && toss_dec != "field") {
    res$status <- 400
    return(list(status = "error", message = "'toss_decision' must be either 'bat' or 'field'."))
  }
  
  # SQL-safe escaped strings
  sql_esc <- function(s) gsub("'", "''", s)
  t1_esc <- sql_esc(t1)
  t2_esc <- sql_esc(t2)
  ven_esc <- sql_esc(ven)
  
  # ----------------------------------------------------------------------------
  # Compute Exact Pre-Match Historical Features from SQLite (Zero Target Leakage)
  # ----------------------------------------------------------------------------
  con <- get_con()
  
  # 1. Cumulative Win Percentages (Laplace Smoothed)
  q_t1_overall <- sprintf("SELECT COUNT(*) AS total, SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) AS wins FROM matches WHERE (team1 = '%s' OR team2 = '%s') AND winner IS NOT NULL AND winner != '';", t1_esc, t1_esc, t1_esc)
  res_t1_ov <- dbGetQuery(con, q_t1_overall)
  t1_win_pct <- (res_t1_ov$wins + 1) / (res_t1_ov$total + 2)
  
  q_t2_overall <- sprintf("SELECT COUNT(*) AS total, SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) AS wins FROM matches WHERE (team1 = '%s' OR team2 = '%s') AND winner IS NOT NULL AND winner != '';", t2_esc, t2_esc, t2_esc)
  res_t2_ov <- dbGetQuery(con, q_t2_overall)
  t2_win_pct <- (res_t2_ov$wins + 1) / (res_t2_ov$total + 2)
  
  win_pct_diff <- t1_win_pct - t2_win_pct
  
  # 2. Recent Form (last 5 matches)
  q_t1_form <- sprintf("SELECT winner FROM matches WHERE (team1 = '%s' OR team2 = '%s') AND winner IS NOT NULL AND winner != '' ORDER BY date DESC LIMIT 5;", t1_esc, t1_esc)
  df_t1_form <- dbGetQuery(con, q_t1_form)
  t1_recent_form <- if (nrow(df_t1_form) > 0) sum(df_t1_form$winner == t1) / nrow(df_t1_form) else 0.50
  
  q_t2_form <- sprintf("SELECT winner FROM matches WHERE (team1 = '%s' OR team2 = '%s') AND winner IS NOT NULL AND winner != '' ORDER BY date DESC LIMIT 5;", t2_esc, t2_esc)
  df_t2_form <- dbGetQuery(con, q_t2_form)
  t2_recent_form <- if (nrow(df_t2_form) > 0) sum(df_t2_form$winner == t2) / nrow(df_t2_form) else 0.50
  
  recent_form_diff <- t1_recent_form - t2_recent_form
  
  # 3. Head-to-Head Win Rate
  q_h2h <- sprintf("SELECT COUNT(*) as total, SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) as wins FROM matches WHERE ((team1 = '%s' AND team2 = '%s') OR (team1 = '%s' AND team2 = '%s')) AND winner IS NOT NULL AND winner != '';", t1_esc, t1_esc, t2_esc, t2_esc, t1_esc)
  df_h2h <- dbGetQuery(con, q_h2h)
  if (df_h2h$total > 0) {
    team1_h2h_win_pct <- (df_h2h$wins + 1) / (df_h2h$total + 2)
    team2_h2h_win_pct <- 1 - team1_h2h_win_pct
  } else {
    team1_h2h_win_pct <- 0.50
    team2_h2h_win_pct <- 0.50
  }
  h2h_diff <- team1_h2h_win_pct - team2_h2h_win_pct
  
  # 4. Venue-Specific Win Rate
  q_t1_ven <- sprintf("SELECT COUNT(*) as total, SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) as wins FROM matches WHERE venue = '%s' AND (team1 = '%s' OR team2 = '%s') AND winner IS NOT NULL AND winner != '';", t1_esc, ven_esc, t1_esc, t1_esc)
  df_t1_ven <- dbGetQuery(con, q_t1_ven)
  team1_venue_win_pct <- (df_t1_ven$wins + 1) / (df_t1_ven$total + 2)
  
  q_t2_ven <- sprintf("SELECT COUNT(*) as total, SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) as wins FROM matches WHERE venue = '%s' AND (team1 = '%s' OR team2 = '%s') AND winner IS NOT NULL AND winner != '';", t2_esc, ven_esc, t2_esc, t2_esc)
  df_t2_ven <- dbGetQuery(con, q_t2_ven)
  team2_venue_win_pct <- (df_t2_ven$wins + 1) / (df_t2_ven$total + 2)
  
  venue_performance_diff <- team1_venue_win_pct - team2_venue_win_pct
  
  # 5. Venue Score & Toss Win Bias
  q_ven_stats <- sprintf("
    SELECT 
      COUNT(*) AS total,
      SUM(CASE WHEN toss_winner = winner THEN 1 ELSE 0 END) AS toss_match_wins
    FROM matches
    WHERE venue = '%s' AND winner IS NOT NULL AND winner != '';
  ", ven_esc)
  df_v_stats <- dbGetQuery(con, q_ven_stats)
  
  venue_toss_win_pct <- if (df_v_stats$total > 0) (df_v_stats$toss_match_wins + 1) / (df_v_stats$total + 2) else 0.50
  
  q_ven_runs <- sprintf("
    SELECT AVG(f.runs) AS avg_score
    FROM (
      SELECT d.match_id, SUM(d.total_runs) AS runs
      FROM deliveries d
      JOIN matches m ON d.match_id = m.id
      WHERE m.venue = '%s' AND d.inning = 1
      GROUP BY d.match_id
    ) f;
  ", ven_esc)
  df_v_runs <- dbGetQuery(con, q_ven_runs)
  venue_average_score <- if (!is.na(df_v_runs$avg_score) && df_v_runs$avg_score > 0) round(df_v_runs$avg_score, 2) else 165.73
  
  dbDisconnect(con)
  
  # 6. Toss indicators
  toss_winner_is_team1 <- ifelse(toss_win == t1, 1, 0)
  toss_decision_bat <- ifelse(toss_dec == "bat", 1, 0)
  is_playoff <- is_ko
  
  # Construct Feature Vector
  features_row <- data.frame(
    win_pct_diff = round(win_pct_diff, 4),
    recent_form_diff = round(recent_form_diff, 4),
    h2h_diff = round(h2h_diff, 4),
    venue_performance_diff = round(venue_performance_diff, 4),
    team1_win_pct = round(t1_win_pct, 4),
    team2_win_pct = round(t2_win_pct, 4),
    team1_recent_form = round(t1_recent_form, 4),
    team2_recent_form = round(t2_recent_form, 4),
    team1_venue_win_pct = round(team1_venue_win_pct, 4),
    team2_venue_win_pct = round(team2_venue_win_pct, 4),
    venue_average_score = round(venue_average_score, 2),
    venue_toss_win_pct = round(venue_toss_win_pct, 4),
    toss_winner_is_team1 = toss_winner_is_team1,
    toss_decision_bat = toss_decision_bat,
    is_playoff = is_playoff,
    stringsAsFactors = FALSE
  )
  
  # Standardized row for distance/gradient models
  features_scaled <- as.data.frame(scale(features_row[, sel_feats], center = mean_vec, scale = sd_vec))
  
  # ----------------------------------------------------------------------------
  # Compute Predictions Across Active Models
  # ----------------------------------------------------------------------------
  model_predictions <- list()
  
  # 1. Logistic Regression
  if ("Logistic Regression" %in% names(models_list)) {
    p_lr <- as.numeric(predict(models_list[["Logistic Regression"]], newdata = features_row, type = "response"))
    model_predictions[["Logistic Regression"]] <- round(p_lr, 4)
  }
  
  # 2. Decision Tree
  if ("Decision Tree" %in% names(models_list)) {
    p_dt <- as.numeric(predict(models_list[["Decision Tree"]], newdata = features_row, type = "prob")[, "1"])
    model_predictions[["Decision Tree"]] <- round(p_dt, 4)
  }
  
  # 3. Random Forest
  if ("Random Forest" %in% names(models_list) && requireNamespace("randomForest", quietly = TRUE)) {
    p_rf <- as.numeric(predict(models_list[["Random Forest"]], newdata = features_row, type = "prob")[, "1"])
    model_predictions[["Random Forest"]] <- round(p_rf, 4)
  }
  
  # 4. KNN
  if ("KNN" %in% names(models_list)) {
    knn_obj <- models_list[["KNN"]]
    knn_res <- class::knn(train = knn_obj$train_x, test = features_scaled, cl = knn_obj$train_y, k = knn_obj$k, prob = TRUE)
    prob_raw <- attr(knn_res, "prob")
    p_knn <- ifelse(knn_res == 1, prob_raw, 1 - prob_raw)
    model_predictions[["KNN"]] <- round(as.numeric(p_knn), 4)
  }
  
  # 5. Naive Bayes
  if ("Naive Bayes" %in% names(models_list) && requireNamespace("e1071", quietly = TRUE)) {
    p_nb <- as.numeric(predict(models_list[["Naive Bayes"]], newdata = features_row, type = "raw")[, "1"])
    model_predictions[["Naive Bayes"]] <- round(p_nb, 4)
  }
  
  # 6. SVM (Radial)
  if ("SVM" %in% names(models_list) && requireNamespace("e1071", quietly = TRUE)) {
    svm_pred <- predict(models_list[["SVM"]], newdata = features_scaled, probability = TRUE)
    p_svm <- as.numeric(attr(svm_pred, "probabilities")[, "1"])
    model_predictions[["SVM"]] <- round(p_svm, 4)
  }
  
  # 7. AdaBoost
  if ("AdaBoost" %in% names(models_list) && requireNamespace("gbm", quietly = TRUE)) {
    p_ada <- as.numeric(predict(models_list[["AdaBoost"]], newdata = features_row, n.trees = 200, type = "response"))
    model_predictions[["AdaBoost"]] <- round(p_ada, 4)
  }
  
  # 8. Gradient Boosting (GBM)
  if ("Gradient Boosting" %in% names(models_list) && requireNamespace("gbm", quietly = TRUE)) {
    p_gbm <- as.numeric(predict(models_list[["Gradient Boosting"]], newdata = features_row, n.trees = 250, type = "response"))
    model_predictions[["Gradient Boosting"]] <- round(p_gbm, 4)
  }
  
  # 9. Neural Network (MLP)
  if ("MLP" %in% names(models_list)) {
    p_mlp <- as.numeric(predict(models_list[["MLP"]], newdata = features_scaled, type = "raw"))
    model_predictions[["MLP"]] <- round(p_mlp, 4)
  }
  
  # Consensus / Selected Model Probability
  all_probs <- unlist(model_predictions)
  consensus_prob <- round(mean(all_probs, na.rm = TRUE), 4)
  
  # Determine primary reported probability
  if (requested_model != "Consensus" && requested_model %in% names(model_predictions)) {
    primary_prob <- model_predictions[[requested_model]]
    model_display <- requested_model
  } else {
    primary_prob <- consensus_prob
    model_display <- "Multi-Model Consensus"
  }
  
  t1_prob <- round(primary_prob * 100, 2)
  t2_prob <- round((1 - primary_prob) * 100, 2)
  predicted_winner <- if (t1_prob >= 50.0) t1 else t2
  win_margin_prob <- abs(round(t1_prob - t2_prob, 2))
  
  # XAI / Feature Impact Explanations
  xai_factors <- list(
    venue_impact = list(
      name = "Venue Familiarity & Ground Record",
      team1_val = round(team1_venue_win_pct * 100, 1),
      team2_val = round(team2_venue_win_pct * 100, 1),
      advantage = if (venue_performance_diff > 0.05) t1 else if (venue_performance_diff < -0.05) t2 else "Neutral"
    ),
    h2h_impact = list(
      name = "Historical Head-to-Head Dominance",
      team1_val = round(team1_h2h_win_pct * 100, 1),
      team2_val = round(team2_h2h_win_pct * 100, 1),
      advantage = if (h2h_diff > 0.05) t1 else if (h2h_diff < -0.05) t2 else "Balanced"
    ),
    form_impact = list(
      name = "Recent 5-Match Form Momentum",
      team1_val = sprintf("%d/5 wins", round(t1_recent_form * 5)),
      team2_val = sprintf("%d/5 wins", round(t2_recent_form * 5)),
      advantage = if (recent_form_diff > 0.1) t1 else if (recent_form_diff < -0.1) t2 else "Even"
    ),
    toss_impact = list(
      name = "Toss Decision & Match Conversion",
      detail = sprintf("%s won toss & chose to %s", toss_win, toss_dec),
      venue_toss_win_pct = round(venue_toss_win_pct * 100, 1),
      advantage = if (toss_winner_is_team1 == 1) t1 else t2
    )
  )
  
  list(
    status = "success",
    match = list(
      team1 = t1,
      team2 = t2,
      venue = ven,
      toss_winner = toss_win,
      toss_decision = toss_dec,
      is_playoff = as.logical(is_playoff)
    ),
    result = list(
      predicted_winner = predicted_winner,
      team1_win_percentage = t1_prob,
      team2_win_percentage = t2_prob,
      confidence_differential = win_margin_prob,
      model_used = model_display
    ),
    all_models_breakdown = model_predictions,
    consensus_probability = consensus_prob,
    computed_features = features_row,
    explainability = xai_factors
  )
}
