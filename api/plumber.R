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

# ------------------------------------------------------------------------------
# 9. Team Detail Endpoint
# ------------------------------------------------------------------------------
#* Return comprehensive historical performance and records for a specific team
#* @get /api/teams/<teamId>
#* @serializer json
function(res, teamId) {
  t_name <- URLdecode(trimws(as.character(teamId)))
  if (t_name == "") {
    res$status <- 400
    return(list(status = "error", message = "teamId parameter is required"))
  }
  
  con <- get_con()
  sql_esc <- function(s) gsub("'", "''", s)
  t_esc <- sql_esc(t_name)
  
  # Overall record
  q_overall <- sprintf("
    SELECT 
      COUNT(*) AS total_matches,
      SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) AS wins,
      SUM(CASE WHEN winner IS NOT NULL AND winner != '' AND winner != '%s' THEN 1 ELSE 0 END) AS losses,
      SUM(CASE WHEN winner IS NULL OR winner = '' THEN 1 ELSE 0 END) AS no_results
    FROM matches
    WHERE team1 = '%s' OR team2 = '%s';
  ", t_esc, t_esc, t_esc, t_esc)
  rec <- dbGetQuery(con, q_overall)
  
  if (rec$total_matches == 0) {
    dbDisconnect(con)
    res$status <- 404
    return(list(status = "error", message = paste("Team", t_name, "not found in dataset")))
  }
  
  # Batting first vs Chasing
  q_bat_first <- sprintf("
    SELECT 
      COUNT(*) AS played,
      SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) AS wins
    FROM matches
    WHERE (team1 = '%s' AND ((toss_winner = '%s' AND toss_decision = 'bat') OR (toss_winner != '%s' AND toss_decision = 'field')))
       OR (team2 = '%s' AND ((toss_winner = '%s' AND toss_decision = 'bat') OR (toss_winner != '%s' AND toss_decision = 'field')));
  ", t_esc, t_esc, t_esc, t_esc, t_esc, t_esc, t_esc)
  bf <- dbGetQuery(con, q_bat_first)
  
  # Season by season
  q_seasons <- sprintf("
    SELECT 
      season,
      COUNT(*) AS played,
      SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) AS wins
    FROM matches
    WHERE team1 = '%s' OR team2 = '%s'
    GROUP BY season
    ORDER BY season ASC;
  ", t_esc, t_esc, t_esc)
  seasons_df <- dbGetQuery(con, q_seasons)
  
  # Venue performance (top 6 venues)
  q_venues <- sprintf("
    SELECT 
      venue,
      COUNT(*) AS played,
      SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) AS wins
    FROM matches
    WHERE team1 = '%s' OR team2 = '%s'
    GROUP BY venue
    HAVING played >= 3
    ORDER BY played DESC
    LIMIT 8;
  ", t_esc, t_esc, t_esc)
  venues_df <- dbGetQuery(con, q_venues)
  
  # Head-to-head vs major opponents
  q_h2h_all <- sprintf("
    SELECT 
      CASE WHEN team1 = '%s' THEN team2 ELSE team1 END AS opponent,
      COUNT(*) AS played,
      SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) AS wins
    FROM matches
    WHERE team1 = '%s' OR team2 = '%s'
    GROUP BY opponent
    HAVING played >= 5
    ORDER BY played DESC;
  ", t_esc, t_esc, t_esc, t_esc)
  h2h_df <- dbGetQuery(con, q_h2h_all)
  
  dbDisconnect(con)
  
  tot <- rec$total_matches
  w <- rec$wins
  l <- rec$losses
  wpct <- round((w / tot) * 100, 2)
  
  bf_played <- bf$played
  bf_wins <- bf$wins
  chase_played <- tot - bf_played
  chase_wins <- w - bf_wins
  
  meta <- team_metadata[[t_name]]
  if (is.null(meta)) meta <- list(short = substr(t_name, 1, 3), primary = "#16a34a", secondary = "#ffffff", titles = 0)
  
  list(
    status = "success",
    team = list(
      name = t_name,
      short_name = meta$short,
      primary_color = meta$primary,
      secondary_color = meta$secondary,
      titles = meta$titles
    ),
    summary = list(
      matches = tot,
      wins = w,
      losses = l,
      no_results = rec$no_results,
      win_pct = wpct,
      batting_first = list(played = bf_played, wins = bf_wins, win_pct = if (bf_played > 0) round((bf_wins/bf_played)*100, 1) else 0),
      chasing = list(played = chase_played, wins = chase_wins, win_pct = if (chase_played > 0) round((chase_wins/chase_played)*100, 1) else 0)
    ),
    seasons = seasons_df,
    top_venues = venues_df,
    head_to_head = h2h_df
  )
}

# ------------------------------------------------------------------------------
# 10. Players Search & Directory Endpoint
# ------------------------------------------------------------------------------
#* Search player names or list prominent IPL players
#* @get /api/players
#* @serializer json
#* @param search:character Optional query prefix/substring
#* @param role:character Optional role filter ('Batsman', 'All-Rounder', 'Bowler')
#* @param limit:int Max suggestions to return (default 30)
function(res, search = "", role = "", limit = 30) {
  con <- get_con()
  term <- trimws(as.character(search))
  r_filter <- trimws(as.character(role))
  lim <- as.integer(limit)
  if (is.na(lim) || lim <= 0 || lim > 150) lim <- 30
  
  sql_esc <- function(s) gsub("'", "''", s)
  term_esc <- sql_esc(term)
  role_esc <- sql_esc(r_filter)
  
  where_outer <- c()
  if (nchar(term_esc) > 0) {
    where_outer <- c(where_outer, sprintf("player_name LIKE '%%%s%%'", term_esc))
  }
  if (nchar(role_esc) > 0 && role_esc != "All") {
    where_outer <- c(where_outer, sprintf("role = '%s'", role_esc))
  }
  
  where_clause <- ""
  if (length(where_outer) > 0) {
    where_clause <- paste("WHERE", paste(where_outer, collapse = " AND "))
  }

  # Dynamic ordering: if looking for bowlers, sort by wickets DESC; otherwise balanced
  order_clause <- if (role_esc == "Bowler") {
    "ORDER BY total_wickets DESC, total_runs DESC"
  } else if (role_esc == "All-Rounder") {
    "ORDER BY (total_runs + total_wickets * 20) DESC"
  } else {
    "ORDER BY total_runs DESC, total_wickets DESC"
  }
  
  # Compute player profile aggregates and derived roles from verified historical delivery counts
  q <- sprintf("
    WITH bat AS (
      SELECT batter AS player_name, COUNT(DISTINCT match_id) AS bat_matches, COUNT(*) AS balls_faced, SUM(batsman_runs) AS runs
      FROM deliveries
      GROUP BY batter
    ),
    bowl AS (
      SELECT bowler AS player_name, COUNT(DISTINCT match_id) AS bowl_matches, COUNT(*) AS balls_bowled,
             SUM(CASE WHEN dismissal_kind IN ('bowled','caught','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) AS wickets
      FROM deliveries
      GROUP BY bowler
    ),
    all_p AS (
      SELECT DISTINCT batter AS player_name FROM deliveries
      UNION
      SELECT DISTINCT bowler AS player_name FROM deliveries
    ),
    classified AS (
      SELECT 
        p.player_name,
        COALESCE(bat.runs, 0) AS total_runs,
        COALESCE(bowl.wickets, 0) AS total_wickets,
        COALESCE(bowl.balls_bowled, 0) AS balls_bowled,
        MAX(COALESCE(bat.bat_matches, 0), COALESCE(bowl.bowl_matches, 0)) AS matches,
        CASE 
          WHEN (COALESCE(bat.runs, 0) >= 500 AND COALESCE(bowl.wickets, 0) >= 15 AND COALESCE(bowl.balls_bowled, 0) >= 400 AND COALESCE(bat.runs, 0) < COALESCE(bowl.balls_bowled, 0) * 3 AND COALESCE(bowl.balls_bowled, 0) > COALESCE(bat.runs, 0) * 0.25)
            OR (COALESCE(bat.runs, 0) >= 1000 AND COALESCE(bowl.wickets, 0) >= 30 AND COALESCE(bowl.balls_bowled, 0) >= 600)
            THEN 'All-Rounder'
          WHEN (COALESCE(bowl.balls_bowled, 0) >= 300 OR COALESCE(bowl.wickets, 0) >= 10) AND (COALESCE(bat.runs, 0) < 600)
            THEN 'Bowler'
          ELSE 'Batsman'
        END AS role
      FROM all_p p
      LEFT JOIN bat ON p.player_name = bat.player_name
      LEFT JOIN bowl ON p.player_name = bowl.player_name
    )
    SELECT * FROM classified
    %s
    %s
    LIMIT %d;
  ", where_clause, order_clause, lim)
  
  players_df <- dbGetQuery(con, q)
  dbDisconnect(con)
  
  players_list <- list()
  if (nrow(players_df) > 0) {
    for (i in 1:nrow(players_df)) {
      players_list[[length(players_list) + 1]] <- list(
        player_name = as.character(players_df$player_name[i]),
        total_runs = as.integer(players_df$total_runs[i]),
        total_wickets = as.integer(players_df$total_wickets[i]),
        matches = as.integer(players_df$matches[i]),
        role = as.character(players_df$role[i])
      )
    }
  }
  
  list(
    status = "success",
    count = length(players_list),
    players = players_list
  )
}

# ------------------------------------------------------------------------------
# 11. Player Profile Endpoint
# ------------------------------------------------------------------------------
#* Return complete batting and bowling profile for a player
#* @get /api/players/<playerId>
#* @serializer json
function(res, playerId) {
  p_name <- URLdecode(trimws(as.character(playerId)))
  if (p_name == "") {
    res$status <- 400
    return(list(status = "error", message = "playerId parameter is required"))
  }
  
  con <- get_con()
  sql_esc <- function(s) gsub("'", "''", s)
  p_esc <- sql_esc(p_name)
  
  # Batting stats
  q_bat <- sprintf("
    SELECT 
      COUNT(DISTINCT match_id) AS matches,
      COUNT(DISTINCT match_id || '-' || inning) AS innings,
      COUNT(*) AS balls_faced,
      SUM(batsman_runs) AS runs,
      SUM(CASE WHEN batsman_runs = 4 THEN 1 ELSE 0 END) AS fours,
      SUM(CASE WHEN batsman_runs = 6 THEN 1 ELSE 0 END) AS sixes,
      SUM(CASE WHEN batsman_runs = 0 AND extra_runs = 0 THEN 1 ELSE 0 END) AS dots
    FROM deliveries
    WHERE batter = '%s';
  ", p_esc)
  bat_df <- dbGetQuery(con, q_bat)
  
  # Dismissals
  q_dism <- sprintf("
    SELECT COUNT(*) AS dismissals 
    FROM deliveries 
    WHERE player_dismissed = '%s' AND is_wicket = 1;
  ", p_esc)
  dism_count <- dbGetQuery(con, q_dism)$dismissals
  
  # Highest score in an innings
  q_hs <- sprintf("
    SELECT MAX(inn_runs) AS highest_score 
    FROM (
      SELECT match_id, inning, SUM(batsman_runs) AS inn_runs 
      FROM deliveries 
      WHERE batter = '%s' 
      GROUP BY match_id, inning
    );
  ", p_esc)
  hs <- dbGetQuery(con, q_hs)$highest_score
  if (is.null(hs) || is.na(hs)) hs <- 0
  
  # Fifties and Hundreds
  q_50_100 <- sprintf("
    SELECT 
      SUM(CASE WHEN inn_runs >= 50 AND inn_runs < 100 THEN 1 ELSE 0 END) AS fifties,
      SUM(CASE WHEN inn_runs >= 100 THEN 1 ELSE 0 END) AS hundreds
    FROM (
      SELECT match_id, inning, SUM(batsman_runs) AS inn_runs 
      FROM deliveries 
      WHERE batter = '%s' 
      GROUP BY match_id, inning
    );
  ", p_esc)
  fifties_hundreds <- dbGetQuery(con, q_50_100)
  
  # Bowling stats
  q_bowl <- sprintf("
    SELECT 
      COUNT(DISTINCT match_id) AS matches,
      COUNT(*) AS balls_bowled,
      SUM(total_runs) AS runs_conceded,
      SUM(CASE WHEN is_wicket = 1 AND dismissal_kind IN ('bowled','caught','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) AS wickets,
      SUM(CASE WHEN total_runs = 0 THEN 1 ELSE 0 END) AS dot_balls
    FROM deliveries
    WHERE bowler = '%s';
  ", p_esc)
  bowl_df <- dbGetQuery(con, q_bowl)
  
  # Teams represented
  q_teams <- sprintf("
    SELECT DISTINCT team FROM (
      SELECT DISTINCT batting_team AS team FROM deliveries WHERE batter = '%s'
      UNION
      SELECT DISTINCT bowling_team AS team FROM deliveries WHERE bowler = '%s'
    );
  ", p_esc, p_esc)
  teams_played <- dbGetQuery(con, q_teams)$team
  
  # Player of match awards
  q_potm <- sprintf("
    SELECT COUNT(*) AS potm_count FROM matches WHERE player_of_match = '%s';
  ", p_esc)
  potm <- dbGetQuery(con, q_potm)$potm_count
  
  # Team Results With This Player (season-by-season and overall)
  q_with <- sprintf("
    SELECT 
      p.player_team, 
      m.season, 
      COUNT(DISTINCT m.id) AS matches_with, 
      SUM(CASE WHEN m.winner = p.player_team THEN 1 ELSE 0 END) AS wins_with, 
      SUM(CASE WHEN m.winner IS NOT NULL AND m.winner != '' AND m.winner != p.player_team AND m.result != 'no result' THEN 1 ELSE 0 END) AS losses_with, 
      SUM(CASE WHEN m.winner IS NULL OR m.winner = '' OR m.result = 'no result' THEN 1 ELSE 0 END) AS no_results_with 
    FROM matches m 
    JOIN (
      SELECT match_id, batting_team AS player_team FROM deliveries WHERE batter = '%s' 
      UNION 
      SELECT match_id, bowling_team AS player_team FROM deliveries WHERE bowler = '%s' 
      UNION 
      SELECT match_id, bowling_team AS player_team FROM deliveries WHERE fielder = '%s'
    ) p ON m.id = p.match_id 
    GROUP BY p.player_team, m.season 
    ORDER BY m.season DESC;
  ", p_esc, p_esc, p_esc)
  with_df <- dbGetQuery(con, q_with)
  
  # All matches for those franchise teams and seasons to compute reliable with/without comparison
  q_all_team_seasons <- "
    SELECT team, season, COUNT(*) AS matches_all,
           SUM(CASE WHEN winner = team THEN 1 ELSE 0 END) AS wins_all,
           SUM(CASE WHEN winner IS NOT NULL AND winner != '' AND winner != team AND result != 'no result' THEN 1 ELSE 0 END) AS losses_all,
           SUM(CASE WHEN winner IS NULL OR winner = '' OR result = 'no result' THEN 1 ELSE 0 END) AS nr_all
    FROM (
      SELECT team1 AS team, season, winner, result FROM matches
      UNION ALL
      SELECT team2 AS team, season, winner, result FROM matches
    )
    GROUP BY team, season;
  "
  all_team_df <- dbGetQuery(con, q_all_team_seasons)
  
  dbDisconnect(con)
  
  # Computations
  bf <- if (!is.na(bat_df$balls_faced)) bat_df$balls_faced else 0
  runs <- if (!is.na(bat_df$runs)) bat_df$runs else 0
  bat_avg <- if (dism_count > 0) round(runs / dism_count, 2) else runs
  sr <- if (bf > 0) round((runs / bf) * 100, 2) else 0
  
  bb <- if (!is.na(bowl_df$balls_bowled)) bowl_df$balls_bowled else 0
  rc <- if (!is.na(bowl_df$runs_conceded)) bowl_df$runs_conceded else 0
  wkts <- if (!is.na(bowl_df$wickets)) bowl_df$wickets else 0
  overs <- round(bb / 6, 1)
  bowl_econ <- if (bb > 0) round((rc / bb) * 6, 2) else 0
  bowl_avg <- if (wkts > 0) round(rc / wkts, 2) else 0

  # Format team results and reliable with/without comparisons
  team_results_list <- list()
  tot_with_m <- 0
  tot_with_w <- 0
  tot_with_l <- 0
  tot_with_nr <- 0
  
  tot_without_m <- 0
  tot_without_w <- 0
  tot_without_l <- 0
  tot_without_nr <- 0
  
  if (nrow(with_df) > 0) {
    for (i in 1:nrow(with_df)) {
      tm <- as.character(with_df$player_team[i])
      sea <- as.character(with_df$season[i])
      m_w <- as.integer(with_df$matches_with[i])
      w_w <- as.integer(with_df$wins_with[i])
      l_w <- as.integer(with_df$losses_with[i])
      nr_w <- as.integer(with_df$no_results_with[i])
      
      tot_with_m <- tot_with_m + m_w
      tot_with_w <- tot_with_w + w_w
      tot_with_l <- tot_with_l + l_w
      tot_with_nr <- tot_with_nr + nr_w
      
      decisive_with <- w_w + l_w
      win_pct_with <- if (decisive_with > 0) round((w_w / decisive_with) * 100, 1) else 0.0
      
      # Match franchise-season totals
      match_row <- all_team_df[all_team_df$team == tm & all_team_df$season == sea, ]
      m_wo <- 0
      w_wo <- 0
      l_wo <- 0
      nr_wo <- 0
      win_pct_wo <- 0.0
      has_without <- FALSE
      
      if (nrow(match_row) > 0) {
        all_m <- as.integer(match_row$matches_all[1])
        all_w <- as.integer(match_row$wins_all[1])
        all_l <- as.integer(match_row$losses_all[1])
        all_nr <- as.integer(match_row$nr_all[1])
        
        m_wo <- max(0, all_m - m_w)
        w_wo <- max(0, all_w - w_w)
        l_wo <- max(0, all_l - l_w)
        nr_wo <- max(0, all_nr - nr_w)
        
        tot_without_m <- tot_without_m + m_wo
        tot_without_w <- tot_without_w + w_wo
        tot_without_l <- tot_without_l + l_wo
        tot_without_nr <- tot_without_nr + nr_wo
        
        if (m_wo > 0) {
          has_without <- TRUE
          decisive_wo <- w_wo + l_wo
          win_pct_wo <- if (decisive_wo > 0) round((w_wo / decisive_wo) * 100, 1) else 0.0
        }
      }
      
      team_results_list[[length(team_results_list) + 1]] <- list(
        team = tm,
        season = sea,
        matches = m_w,
        wins = w_w,
        losses = l_w,
        no_results = nr_w,
        win_percentage = win_pct_with,
        matches_without = m_wo,
        wins_without = w_wo,
        losses_without = l_wo,
        no_results_without = nr_wo,
        win_percentage_without = if (has_without) win_pct_wo else NA,
        has_without_data = has_without
      )
    }
  }
  
  overall_decisive_with <- tot_with_w + tot_with_l
  overall_win_pct_with <- if (overall_decisive_with > 0) round((tot_with_w / overall_decisive_with) * 100, 1) else 0.0
  overall_decisive_wo <- tot_without_w + tot_without_l
  overall_win_pct_wo <- if (overall_decisive_wo > 0) round((tot_without_w / overall_decisive_wo) * 100, 1) else 0.0
  diff_pct_points <- round(overall_win_pct_with - overall_win_pct_wo, 1)
  
  list(
    status = "success",
    player = list(
      name = p_name,
      teams = teams_played,
      player_of_match_awards = potm
    ),
    batting = list(
      matches = bat_df$matches,
      innings = bat_df$innings,
      runs = runs,
      balls = bf,
      average = bat_avg,
      strike_rate = sr,
      highest_score = hs,
      fifties = fifties_hundreds$fifties,
      hundreds = fifties_hundreds$hundreds,
      fours = bat_df$fours,
      sixes = bat_df$sixes,
      dismissals = dism_count
    ),
    bowling = list(
      matches = bowl_df$matches,
      overs = overs,
      balls = bb,
      wickets = wkts,
      runs_conceded = rc,
      economy = bowl_econ,
      average = bowl_avg,
      dot_balls = bowl_df$dot_balls
    ),
    team_results = list(
      summary = list(
        matches = tot_with_m,
        wins = tot_with_w,
        losses = tot_with_l,
        no_results = tot_with_nr,
        win_percentage = overall_win_pct_with,
        formula = "wins / (wins + losses) * 100 [decisive matches]",
        matches_without = tot_without_m,
        wins_without = tot_without_w,
        losses_without = tot_without_l,
        no_results_without = tot_without_nr,
        win_percentage_without = if (tot_without_m > 0) overall_win_pct_wo else NA,
        diff_pct_points = if (tot_without_m > 0) diff_pct_points else NA,
        association_disclaimer = "Historical association only: does not prove player caused team outcome. Opponents, venues, team composition, and seasons vary."
      ),
      seasons = team_results_list,
      data_limitation = "Player participation is identified from official delivery records (batting, bowling, or fielding dismissals/catches). Players who did not bat, bowl, or record a fielding dismissal in a fixture are unrecorded as official playing-XI members in this delivery dataset."
    )
  )
}

# ------------------------------------------------------------------------------
# 12. Stats & Historical Records Endpoint
# ------------------------------------------------------------------------------
#* Aggregated historical tournament statistics with filters
#* @get /api/stats
#* @serializer json
#* @param season:character Optional season filter
#* @param team:character Optional team filter
function(res, season = "", team = "") {
  con <- get_con()
  sql_esc <- function(s) gsub("'", "''", s)
  
  sea <- trimws(as.character(season))
  tm <- trimws(as.character(team))
  
  where_matches <- "WHERE 1=1"
  if (sea != "") where_matches <- paste0(where_matches, sprintf(" AND season = '%s'", sql_esc(sea)))
  if (tm != "") where_matches <- paste0(where_matches, sprintf(" AND (team1 = '%s' OR team2 = '%s')", sql_esc(tm), sql_esc(tm)))
  
  # Overall match totals
  q_tot <- sprintf("
    SELECT 
      COUNT(*) AS matches_count,
      COUNT(DISTINCT season) AS seasons_count,
      COUNT(DISTINCT venue) AS venues_count
    FROM matches %s;
  ", where_matches)
  tot_df <- dbGetQuery(con, q_tot)
  
  # Top Run Scorers (within filter)
  q_top_bat <- sprintf("
    SELECT 
      d.batter,
      SUM(d.batsman_runs) AS runs,
      COUNT(DISTINCT d.match_id) AS matches,
      ROUND((SUM(d.batsman_runs)*1.0 / COUNT(*)) * 100, 2) AS strike_rate
    FROM deliveries d
    JOIN matches m ON d.match_id = m.id
    %s
    GROUP BY d.batter
    ORDER BY runs DESC
    LIMIT 10;
  ", where_matches)
  top_bat <- dbGetQuery(con, q_top_bat)
  
  # Top Wicket Takers
  q_top_bowl <- sprintf("
    SELECT 
      d.bowler,
      SUM(d.is_wicket) AS wickets,
      COUNT(DISTINCT d.match_id) AS matches,
      ROUND((SUM(d.total_runs)*6.0 / COUNT(*)), 2) AS economy
    FROM deliveries d
    JOIN matches m ON d.match_id = m.id
    %s AND d.dismissal_kind IN ('bowled','caught','lbw','stumped','caught and bowled','hit wicket')
    GROUP BY d.bowler
    ORDER BY wickets DESC
    LIMIT 10;
  ", where_matches)
  top_bowl <- dbGetQuery(con, q_top_bowl)
  
  # Available filter choices
  seasons_list <- dbGetQuery(con, "SELECT DISTINCT season FROM matches ORDER BY season DESC;")$season
  teams_list <- dbGetQuery(con, "SELECT DISTINCT team1 AS team FROM matches ORDER BY team;")$team
  
  dbDisconnect(con)
  
  list(
    status = "success",
    filters = list(
      available_seasons = seasons_list,
      available_teams = teams_list
    ),
    summary = tot_df,
    top_run_scorers = top_bat,
    top_wicket_takers = top_bowl
  )
}

# ------------------------------------------------------------------------------
# 13. Batsman vs Bowler Matchup Endpoint
# ------------------------------------------------------------------------------
#* Calculate head-to-head encounter records between a batsman and a bowler
#* @get /api/batter-bowler
#* @serializer json
#* @param batsman:character Batsman name
#* @param bowler:character Bowler name
#* @param venue:character Optional venue filter
#* @param phase:character Optional phase filter ('powerplay', 'middle', 'death', 'all')
function(res, batsman = "", bowler = "", venue = "", phase = "") {
  bat <- trimws(as.character(batsman))
  bwl <- trimws(as.character(bowler))
  ven <- trimws(as.character(venue))
  ph <- tolower(trimws(as.character(phase)))
  
  if (bat == "" || bwl == "") {
    res$status <- 400
    return(list(status = "error", message = "Both 'batsman' and 'bowler' query parameters are required"))
  }
  
  con <- get_con()
  sql_esc <- function(s) gsub("'", "''", s)
  bat_esc <- sql_esc(bat)
  bwl_esc <- sql_esc(bwl)
  ven_esc <- sql_esc(ven)
  
  # Build where clauses
  where_h2h <- sprintf("WHERE d.batter = '%s' AND d.bowler = '%s'", bat_esc, bwl_esc)
  if (ven_esc != "" && ven_esc != "All") {
    where_h2h <- paste0(where_h2h, sprintf(" AND m.venue = '%s'", ven_esc))
  }
  if (ph == "powerplay") {
    where_h2h <- paste0(where_h2h, " AND d.over >= 0 AND d.over <= 5")
  } else if (ph == "middle") {
    where_h2h <- paste0(where_h2h, " AND d.over >= 6 AND d.over <= 14")
  } else if (ph == "death") {
    where_h2h <- paste0(where_h2h, " AND d.over >= 15 AND d.over <= 19")
  }
  
  # 1. Head-to-Head Encounter with filter
  q <- sprintf("
    SELECT 
      COUNT(DISTINCT d.match_id) AS matches_count,
      COUNT(*) AS total_balls,
      SUM(d.batsman_runs) AS runs_scored,
      SUM(d.total_runs) AS total_runs_conceded,
      SUM(CASE WHEN d.is_wicket = 1 AND d.player_dismissed = '%s' AND d.dismissal_kind IN ('bowled','caught','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) AS dismissals,
      SUM(CASE WHEN d.batsman_runs = 0 AND d.extra_runs = 0 THEN 1 ELSE 0 END) AS dot_balls,
      SUM(CASE WHEN d.batsman_runs = 4 THEN 1 ELSE 0 END) AS fours,
      SUM(CASE WHEN d.batsman_runs = 6 THEN 1 ELSE 0 END) AS sixes,
      SUM(CASE WHEN d.extra_runs > 0 THEN 1 ELSE 0 END) AS extras_balls
    FROM deliveries d
    JOIN matches m ON d.match_id = m.id
    %s;
  ", bat_esc, where_h2h)
  
  h2h_res <- dbGetQuery(con, q)
  
  # 2. Phase Breakdown for this matchup
  q_phase <- sprintf("
    SELECT 
      CASE 
        WHEN d.over <= 5 THEN 'Powerplay (0-5)'
        WHEN d.over <= 14 THEN 'Middle Overs (6-14)'
        ELSE 'Death Overs (15-19)'
      END AS match_phase,
      COUNT(*) AS balls,
      SUM(d.batsman_runs) AS runs,
      SUM(CASE WHEN d.is_wicket = 1 AND d.player_dismissed = '%s' AND d.dismissal_kind IN ('bowled','caught','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) AS dismissals,
      SUM(CASE WHEN d.batsman_runs = 0 AND d.extra_runs = 0 THEN 1 ELSE 0 END) AS dots
    FROM deliveries d
    JOIN matches m ON d.match_id = m.id
    WHERE d.batter = '%s' AND d.bowler = '%s'
    GROUP BY match_phase
    ORDER BY MIN(d.over);
  ", bat_esc, bat_esc, bwl_esc)
  phase_df <- dbGetQuery(con, q_phase)
  
  # 3. Overall Career Baselines for both players to generate evidence-based tactical insights
  q_bat_base <- sprintf("
    SELECT COUNT(*) AS total_balls, SUM(batsman_runs) AS total_runs,
           SUM(CASE WHEN batsman_runs = 0 AND extra_runs = 0 THEN 1 ELSE 0 END) AS total_dots,
           SUM(CASE WHEN is_wicket = 1 AND player_dismissed = '%s' THEN 1 ELSE 0 END) AS total_dism
    FROM deliveries WHERE batter = '%s';
  ", bat_esc, bat_esc)
  bat_base <- dbGetQuery(con, q_bat_base)
  
  q_bowl_base <- sprintf("
    SELECT COUNT(*) AS total_balls, SUM(total_runs) AS runs_conceded,
           SUM(CASE WHEN is_wicket = 1 AND dismissal_kind IN ('bowled','caught','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) AS total_wkts,
           SUM(CASE WHEN batsman_runs = 0 AND extra_runs = 0 THEN 1 ELSE 0 END) AS total_dots
    FROM deliveries WHERE bowler = '%s';
  ", bwl_esc)
  bowl_base <- dbGetQuery(con, q_bowl_base)
  
  # 4. Available venues where both played
  q_venues <- sprintf("
    SELECT DISTINCT m.venue 
    FROM deliveries d
    JOIN matches m ON d.match_id = m.id
    WHERE d.batter = '%s' AND d.bowler = '%s'
    ORDER BY m.venue;
  ", bat_esc, bwl_esc)
  venues_list <- dbGetQuery(con, q_venues)$venue
  
  dbDisconnect(con)
  
  m <- if (!is.na(h2h_res$matches_count)) as.integer(h2h_res$matches_count) else 0
  balls <- if (!is.na(h2h_res$total_balls)) as.integer(h2h_res$total_balls) else 0
  runs <- if (!is.na(h2h_res$runs_scored)) as.integer(h2h_res$runs_scored) else 0
  dism <- if (!is.na(h2h_res$dismissals)) as.integer(h2h_res$dismissals) else 0
  dots <- if (!is.na(h2h_res$dot_balls)) as.integer(h2h_res$dot_balls) else 0
  fours <- if (!is.na(h2h_res$fours)) as.integer(h2h_res$fours) else 0
  sixes <- if (!is.na(h2h_res$sixes)) as.integer(h2h_res$sixes) else 0
  
  sr <- if (balls > 0) round((runs / balls) * 100, 1) else 0.0
  avg <- if (dism > 0) round(runs / dism, 1) else runs
  dot_pct <- if (balls > 0) round((dots / balls) * 100, 1) else 0.0
  boundary_runs <- (fours * 4) + (sixes * 6)
  boundary_pct <- if (runs > 0) round((boundary_runs / runs) * 100, 1) else 0.0
  balls_per_dism <- if (dism > 0) round(balls / dism, 1) else balls
  
  # Career baselines
  bat_career_balls <- as.integer(bat_base$total_balls[1])
  bat_career_runs <- as.integer(bat_base$total_runs[1])
  bat_career_sr <- if (bat_career_balls > 0) round((bat_career_runs / bat_career_balls) * 100, 1) else 0.0
  
  bowl_career_balls <- as.integer(bowl_base$total_balls[1])
  bowl_career_rc <- as.integer(bowl_base$runs_conceded[1])
  bowl_career_econ <- if (bowl_career_balls > 0) round((bowl_career_rc / bowl_career_balls) * 6, 2) else 0.0
  
  # Generate Evidence-Based Tactical Insights
  tactical_insights <- list()
  if (balls >= 10) {
    # Scoring rate comparison
    sr_diff <- round(sr - bat_career_sr, 1)
    if (sr_diff >= 15.0) {
      tactical_insights[[length(tactical_insights) + 1]] <- sprintf("%s strikes at %.1f against %s, +%.1f pts above their overall IPL career baseline (%.1f SR).", bat, sr, bwl, sr_diff, bat_career_sr)
    } else if (sr_diff <= -15.0) {
      tactical_insights[[length(tactical_insights) + 1]] <- sprintf("%s scoring suppressed to %.1f SR by %s, %.1f pts below career average (%.1f SR).", bat, sr, bwl, abs(sr_diff), bat_career_sr)
    } else {
      tactical_insights[[length(tactical_insights) + 1]] <- sprintf("%s scoring rate (%.1f SR) against %s is comparable to career baseline (%.1f SR).", bat, sr, bwl, bat_career_sr)
    }
    
    # Dismissal vulnerability
    if (dism >= 3) {
      tactical_insights[[length(tactical_insights) + 1]] <- sprintf("%s has dismissed %s %d times across %d balls faced (averaging a dismissal every %.1f balls).", bwl, bat, dism, balls, balls_per_dism)
    } else if (dism == 0 && balls >= 25) {
      tactical_insights[[length(tactical_insights) + 1]] <- sprintf("%s has never dismissed %s in official IPL encounters across %d deliveries.", bwl, bat, balls)
    }
    
    # Dot ball pressure
    if (dot_pct >= 45.0) {
      tactical_insights[[length(tactical_insights) + 1]] <- sprintf("High dot-ball suppression: %.1f%% of deliveries faced by %s against %s resulted in 0 runs.", dot_pct, bat, bwl)
    }
  } else if (balls > 0) {
    tactical_insights[[length(tactical_insights) + 1]] <- sprintf("Sample size is limited (%d balls faced). Caution advised before generalizing tactical dominance.", balls)
  } else {
    tactical_insights[[length(tactical_insights) + 1]] <- "No direct deliveries recorded between this batsman and bowler under current filters."
  }
  
  # Format Phase breakdown
  phases_list <- list()
  if (nrow(phase_df) > 0) {
    for (i in 1:nrow(phase_df)) {
      p_balls <- as.integer(phase_df$balls[i])
      p_runs <- as.integer(phase_df$runs[i])
      p_dism <- as.integer(phase_df$dismissals[i])
      p_dots <- as.integer(phase_df$dots[i])
      phases_list[[length(phases_list) + 1]] <- list(
        phase = as.character(phase_df$match_phase[i]),
        balls = p_balls,
        runs = p_runs,
        dismissals = p_dism,
        dots = p_dots,
        strike_rate = if (p_balls > 0) round((p_runs / p_balls) * 100, 1) else 0.0,
        dot_pct = if (p_balls > 0) round((p_dots / p_balls) * 100, 1) else 0.0
      )
    }
  }
  
  list(
    status = "success",
    matchup = list(
      batsman = bat,
      bowler = bwl,
      active_venue = if (ven_esc != "") ven_esc else "All Venues",
      active_phase = if (ph != "") ph else "all"
    ),
    stats = list(
      matches = m,
      balls = balls,
      runs = runs,
      dismissals = dism,
      dots = dots,
      dot_pct = dot_pct,
      fours = fours,
      sixes = sixes,
      strike_rate = sr,
      average = avg,
      boundary_pct = boundary_pct,
      balls_per_dismissal = balls_per_dism
    ),
    baselines = list(
      batsman_career_sr = bat_career_sr,
      bowler_career_economy = bowl_career_econ
    ),
    phases = phases_list,
    tactical_insights = tactical_insights,
    available_venues = venues_list,
    ball_length_supported = FALSE,
    shot_type_supported = FALSE,
    note = "Ball trajectory coordinates, pitch lengths, and stroke shot classifications are not recorded in this official IPL delivery dataset."
  )
}

# ------------------------------------------------------------------------------
# 14. MY11 Lineup Calculation Endpoint
# ------------------------------------------------------------------------------
#* Calculate defensible historical team-win metrics for user-constructed playing XI
#* @post /api/my11
#* @serializer json
function(req, res) {
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
  
  if (is.null(body_data$players)) {
    res$status <- 400
    return(list(status = "error", message = "Request body must contain a 'players' array."))
  }
  
  players_raw <- as.character(body_data$players)
  players <- trimws(players_raw[players_raw != ""])
  
  # Validation 1: Exactly 11 unique players
  if (length(players) != 11) {
    res$status <- 400
    return(list(status = "error", message = sprintf("Playing XI must contain exactly 11 players. Received %d.", length(players))))
  }
  if (length(unique(players)) != 11) {
    res$status <- 400
    return(list(status = "error", message = "Duplicate players detected. All 11 players must be distinct."))
  }
  
  con <- get_con()
  sql_esc <- function(s) gsub("'", "''", s)
  players_esc <- sapply(players, sql_esc)
  in_clause <- paste(sprintf("'%s'", players_esc), collapse = ", ")
  
  # Fetch verified stats and derive primary roles for each player
  q_roles <- sprintf("
    WITH bat AS (
      SELECT batter AS player_name, COUNT(DISTINCT match_id) AS bat_matches, COUNT(*) AS balls_faced, SUM(batsman_runs) AS runs
      FROM deliveries
      WHERE batter IN (%s)
      GROUP BY batter
    ),
    bowl AS (
      SELECT bowler AS player_name, COUNT(DISTINCT match_id) AS bowl_matches, COUNT(*) AS balls_bowled,
             SUM(CASE WHEN dismissal_kind IN ('bowled','caught','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) AS wickets
      FROM deliveries
      WHERE bowler IN (%s)
      GROUP BY bowler
    ),
    all_p AS (
      SELECT DISTINCT batter AS player_name FROM deliveries WHERE batter IN (%s)
      UNION
      SELECT DISTINCT bowler AS player_name FROM deliveries WHERE bowler IN (%s)
    )
    SELECT 
      p.player_name,
      COALESCE(bat.runs, 0) AS total_runs,
      COALESCE(bowl.wickets, 0) AS total_wickets,
      COALESCE(bowl.balls_bowled, 0) AS balls_bowled,
      MAX(COALESCE(bat.bat_matches, 0), COALESCE(bowl.bowl_matches, 0)) AS matches,
      CASE 
        WHEN (COALESCE(bat.runs, 0) >= 500 AND COALESCE(bowl.wickets, 0) >= 15 AND COALESCE(bowl.balls_bowled, 0) >= 400 AND COALESCE(bat.runs, 0) < COALESCE(bowl.balls_bowled, 0) * 3 AND COALESCE(bowl.balls_bowled, 0) > COALESCE(bat.runs, 0) * 0.25)
          OR (COALESCE(bat.runs, 0) >= 1000 AND COALESCE(bowl.wickets, 0) >= 30 AND COALESCE(bowl.balls_bowled, 0) >= 600)
          THEN 'All-Rounder'
        WHEN (COALESCE(bowl.balls_bowled, 0) >= 300 OR COALESCE(bowl.wickets, 0) >= 10) AND (COALESCE(bat.runs, 0) < 600)
          THEN 'Bowler'
        ELSE 'Batsman'
      END AS role
    FROM all_p p
    LEFT JOIN bat ON p.player_name = bat.player_name
    LEFT JOIN bowl ON p.player_name = bowl.player_name;
  ", in_clause, in_clause, in_clause, in_clause)
  
  roles_df <- dbGetQuery(con, q_roles)
  
  # Map user custom roles or fallback to derived roles
  user_roles <- if (!is.null(body_data$roles) && is.list(body_data$roles)) body_data$roles else list()
  
  player_details <- list()
  batsmen_count <- 0
  all_rounders_count <- 0
  bowlers_count <- 0
  
  for (p in players) {
    match_row <- roles_df[roles_df$player_name == p, ]
    derived_role <- if (nrow(match_row) > 0) as.character(match_row$role[1]) else "Batsman"
    runs_val <- if (nrow(match_row) > 0) as.integer(match_row$total_runs[1]) else 0
    wkts_val <- if (nrow(match_row) > 0) as.integer(match_row$total_wickets[1]) else 0
    m_val <- if (nrow(match_row) > 0) as.integer(match_row$matches[1]) else 0
    
    # Check if user specified a valid role
    assigned_role <- derived_role
    is_user_assigned <- FALSE
    if (!is.null(user_roles[[p]])) {
      u_role <- as.character(user_roles[[p]])
      if (u_role %in% c("Batsman", "All-Rounder", "Bowler")) {
        assigned_role <- u_role
        is_user_assigned <- (assigned_role != derived_role)
      }
    }
    
    if (assigned_role == "Batsman") batsmen_count <- batsmen_count + 1
    if (assigned_role == "All-Rounder") all_rounders_count <- all_rounders_count + 1
    if (assigned_role == "Bowler") bowlers_count <- bowlers_count + 1
    
    player_details[[length(player_details) + 1]] <- list(
      name = p,
      role = assigned_role,
      derived_role = derived_role,
      is_user_assigned = is_user_assigned,
      runs = runs_val,
      wickets = wkts_val,
      matches = m_val
    )
  }
  
  # Role Minimums Validation: >= 2 Batsmen, >= 1 All-Rounder, >= 5 Bowlers
  valid_lineup <- (batsmen_count >= 2 && all_rounders_count >= 1 && bowlers_count >= 5)
  if (!valid_lineup) {
    dbDisconnect(con)
    res$status <- 400
    return(list(
      status = "error",
      message = sprintf("Lineup composition requirements not met: minimum 2 batsmen (current: %d), 1 all-rounder (current: %d), 5 bowlers (current: %d).",
                        batsmen_count, all_rounders_count, bowlers_count),
      requirements = list(
        batsmen = list(current = batsmen_count, required = 2, satisfied = (batsmen_count >= 2)),
        all_rounders = list(current = all_rounders_count, required = 1, satisfied = (all_rounders_count >= 1)),
        bowlers = list(current = bowlers_count, required = 5, satisfied = (bowlers_count >= 5))
      )
    ))
  }
  
  # ----------------------------------------------------------------------------
  # Method A — Exact Historical Playing XI (Preferred)
  # ----------------------------------------------------------------------------
  q_exact <- sprintf("
    SELECT m.id, m.season, m.date, m.venue, p.team, m.winner, m.result
    FROM matches m
    JOIN (
      SELECT match_id, batting_team AS team, batter AS player FROM deliveries WHERE batter IN (%s)
      UNION
      SELECT match_id, bowling_team AS team, bowler AS player FROM deliveries WHERE bowler IN (%s)
      UNION
      SELECT match_id, bowling_team AS team, fielder AS player FROM deliveries WHERE fielder IN (%s)
    ) p ON m.id = p.match_id
    GROUP BY m.id, p.team
    HAVING COUNT(DISTINCT p.player) = 11;
  ", in_clause, in_clause, in_clause)
  
  exact_df <- dbGetQuery(con, q_exact)
  exact_available <- nrow(exact_df) > 0
  exact_summary <- NULL
  
  if (exact_available) {
    exact_w <- sum(exact_df$winner == exact_df$team, na.rm = TRUE)
    exact_l <- sum(exact_df$winner != exact_df$team & !is.na(exact_df$winner) & exact_df$winner != "" & exact_df$result != "no result", na.rm = TRUE)
    exact_nr <- sum(is.na(exact_df$winner) | exact_df$winner == "" | exact_df$result == "no result", na.rm = TRUE)
    exact_decisive <- exact_w + exact_l
    exact_win_pct <- if (exact_decisive > 0) round((exact_w / exact_decisive) * 100, 1) else 0.0
    
    exact_matches_list <- list()
    for (i in 1:nrow(exact_df)) {
      exact_matches_list[[length(exact_matches_list) + 1]] <- list(
        id = exact_df$id[i],
        season = exact_df$season[i],
        date = exact_df$date[i],
        team = exact_df$team[i],
        venue = exact_df$venue[i],
        winner = exact_df$winner[i],
        won = (exact_df$winner[i] == exact_df$team[i])
      )
    }
    
    exact_summary <- list(
      matches = nrow(exact_df),
      wins = exact_w,
      losses = exact_l,
      no_results = exact_nr,
      win_percentage = exact_win_pct,
      formula = "wins / (wins + losses) * 100 [exact 11-player lineup matches]",
      matches_list = exact_matches_list
    )
  }
  
  # ----------------------------------------------------------------------------
  # Method B — Historical Team Matches Involving Selected Players
  # ----------------------------------------------------------------------------
  # 1. Distinct matches where selected players played together for the same franchise team
  q_co_occurrence <- sprintf("
    SELECT 
      m.id, 
      m.season, 
      p.team, 
      COUNT(DISTINCT p.player) AS players_present, 
      m.winner, 
      m.result
    FROM matches m
    JOIN (
      SELECT match_id, batting_team AS team, batter AS player FROM deliveries WHERE batter IN (%s)
      UNION
      SELECT match_id, bowling_team AS team, bowler AS player FROM deliveries WHERE bowler IN (%s)
      UNION
      SELECT match_id, bowling_team AS team, fielder AS player FROM deliveries WHERE fielder IN (%s)
    ) p ON m.id = p.match_id
    GROUP BY m.id, p.team;
  ", in_clause, in_clause, in_clause)
  co_df <- dbGetQuery(con, q_co_occurrence)
  
  # Filter to matches where at least 3 selected players shared the same franchise side
  co_qualifying <- co_df[co_df$players_present >= 3, ]
  has_co <- nrow(co_qualifying) > 0
  
  co_w <- if (has_co) sum(co_qualifying$winner == co_qualifying$team, na.rm = TRUE) else 0
  co_l <- if (has_co) sum(co_qualifying$winner != co_qualifying$team & !is.na(co_qualifying$winner) & co_qualifying$winner != "" & co_qualifying$result != "no result", na.rm = TRUE) else 0
  co_nr <- if (has_co) sum(is.na(co_qualifying$winner) | co_qualifying$winner == "" | co_qualifying$result == "no result", na.rm = TRUE) else 0
  co_decisive <- co_w + co_l
  co_win_pct <- if (co_decisive > 0) round((co_w / co_decisive) * 100, 1) else 0.0
  
  # 2. Individual player historical team win rates for transparent comparison
  q_indiv <- sprintf("
    SELECT 
      p.player,
      COUNT(DISTINCT m.id) AS matches_count,
      SUM(CASE WHEN m.winner = p.team THEN 1 ELSE 0 END) AS wins,
      SUM(CASE WHEN m.winner IS NOT NULL AND m.winner != '' AND m.winner != p.team AND m.result != 'no result' THEN 1 ELSE 0 END) AS losses,
      SUM(CASE WHEN m.winner IS NULL OR m.winner = '' OR m.result = 'no result' THEN 1 ELSE 0 END) AS no_results
    FROM (
      SELECT match_id, batting_team AS team, batter AS player FROM deliveries WHERE batter IN (%s)
      UNION
      SELECT match_id, bowling_team AS team, bowler AS player FROM deliveries WHERE bowler IN (%s)
      UNION
      SELECT match_id, bowling_team AS team, fielder AS player FROM deliveries WHERE fielder IN (%s)
    ) p
    JOIN matches m ON p.match_id = m.id
    GROUP BY p.player;
  ", in_clause, in_clause, in_clause)
  indiv_df <- dbGetQuery(con, q_indiv)
  
  player_breakdown_list <- list()
  for (i in 1:nrow(indiv_df)) {
    p_name <- indiv_df$player[i]
    m_cnt <- as.integer(indiv_df$matches_count[i])
    w_cnt <- as.integer(indiv_df$wins[i])
    l_cnt <- as.integer(indiv_df$losses[i])
    nr_cnt <- as.integer(indiv_df$no_results[i])
    dec_cnt <- w_cnt + l_cnt
    pct_val <- if (dec_cnt > 0) round((w_cnt / dec_cnt) * 100, 1) else 0.0
    
    player_breakdown_list[[length(player_breakdown_list) + 1]] <- list(
      player = p_name,
      matches = m_cnt,
      wins = w_cnt,
      losses = l_cnt,
      no_results = nr_cnt,
      win_percentage = pct_val
    )
  }
  
  # Optional venue and opponent filters
  venue_filter <- if (!is.null(body_data$venue) && body_data$venue != "" && body_data$venue != "All") trimws(as.character(body_data$venue)) else ""
  opponent_filter <- if (!is.null(body_data$opponent) && body_data$opponent != "" && body_data$opponent != "All") trimws(as.character(body_data$opponent)) else ""
  ven_esc <- sql_esc(venue_filter)
  opp_esc <- sql_esc(opponent_filter)

  # Fetch venue-specific records for selected players if venue provided
  venue_player_stats <- list()
  if (venue_filter != "") {
    q_ven_p <- sprintf("
      SELECT 
        d.batter AS player,
        COUNT(DISTINCT d.match_id) AS v_matches,
        COUNT(*) AS v_balls,
        SUM(d.batsman_runs) AS v_runs,
        ROUND((SUM(d.batsman_runs)*1.0 / NULLIF(COUNT(*), 0)) * 100, 1) AS v_sr
      FROM deliveries d
      JOIN matches m ON d.match_id = m.id
      WHERE d.batter IN (%s) AND m.venue = '%s'
      GROUP BY d.batter;
    ", in_clause, ven_esc)
    v_bat_df <- dbGetQuery(con, q_ven_p)
    
    q_ven_bowl <- sprintf("
      SELECT 
        d.bowler AS player,
        COUNT(DISTINCT d.match_id) AS v_matches,
        COUNT(*) AS v_balls,
        SUM(CASE WHEN d.is_wicket = 1 AND d.dismissal_kind IN ('bowled','caught','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) AS v_wkts,
        ROUND((SUM(d.total_runs)*6.0 / NULLIF(COUNT(*), 0)), 2) AS v_econ
      FROM deliveries d
      JOIN matches m ON d.match_id = m.id
      WHERE d.bowler IN (%s) AND m.venue = '%s'
      GROUP BY d.bowler;
    ", in_clause, ven_esc)
    v_bowl_df <- dbGetQuery(con, q_ven_bowl)
    
    for (p in players) {
      vb <- v_bat_df[v_bat_df$player == p, ]
      vbw <- v_bowl_df[v_bowl_df$player == p, ]
      venue_player_stats[[p]] <- list(
        venue = venue_filter,
        bat_matches = if (nrow(vb) > 0) as.integer(vb$v_matches[1]) else 0,
        runs = if (nrow(vb) > 0) as.integer(vb$v_runs[1]) else 0,
        sr = if (nrow(vb) > 0 && !is.na(vb$v_sr[1])) as.numeric(vb$v_sr[1]) else 0.0,
        bowl_matches = if (nrow(vbw) > 0) as.integer(vbw$v_matches[1]) else 0,
        wickets = if (nrow(vbw) > 0) as.integer(vbw$v_wkts[1]) else 0,
        econ = if (nrow(vbw) > 0 && !is.na(vbw$v_econ[1])) as.numeric(vbw$v_econ[1]) else 0.0
      )
    }
  }

  # Fetch opponent-specific records for selected players if opponent provided
  opp_player_stats <- list()
  if (opponent_filter != "") {
    q_opp_p <- sprintf("
      SELECT 
        d.batter AS player,
        COUNT(DISTINCT d.match_id) AS opp_matches,
        SUM(d.batsman_runs) AS opp_runs,
        ROUND((SUM(d.batsman_runs)*1.0 / NULLIF(COUNT(*), 0)) * 100, 1) AS opp_sr
      FROM deliveries d
      WHERE d.batter IN (%s) AND d.bowling_team = '%s'
      GROUP BY d.batter;
    ", in_clause, opp_esc)
    opp_bat_df <- dbGetQuery(con, q_opp_p)
    
    q_opp_bowl <- sprintf("
      SELECT 
        d.bowler AS player,
        COUNT(DISTINCT d.match_id) AS opp_matches,
        SUM(CASE WHEN d.is_wicket = 1 AND d.dismissal_kind IN ('bowled','caught','lbw','stumped','caught and bowled','hit wicket') THEN 1 ELSE 0 END) AS opp_wkts,
        ROUND((SUM(d.total_runs)*6.0 / NULLIF(COUNT(*), 0)), 2) AS opp_econ
      FROM deliveries d
      WHERE d.bowler IN (%s) AND d.batting_team = '%s'
      GROUP BY d.bowler;
    ", in_clause, opp_esc)
    opp_bowl_df <- dbGetQuery(con, q_opp_bowl)
    
    for (p in players) {
      ob <- opp_bat_df[opp_bat_df$player == p, ]
      obw <- opp_bowl_df[opp_bowl_df$player == p, ]
      opp_player_stats[[p]] <- list(
        opponent = opponent_filter,
        bat_matches = if (nrow(ob) > 0) as.integer(ob$opp_matches[1]) else 0,
        runs = if (nrow(ob) > 0) as.integer(ob$opp_runs[1]) else 0,
        sr = if (nrow(ob) > 0 && !is.na(ob$opp_sr[1])) as.numeric(ob$opp_sr[1]) else 0.0,
        bowl_matches = if (nrow(obw) > 0) as.integer(obw$opp_matches[1]) else 0,
        wickets = if (nrow(obw) > 0) as.integer(obw$opp_wkts[1]) else 0,
        econ = if (nrow(obw) > 0 && !is.na(obw$opp_econ[1])) as.numeric(obw$opp_econ[1]) else 0.0
      )
    }
  }

  # Venue general analytics if requested
  venue_report <- NULL
  if (venue_filter != "") {
    q_vr <- sprintf("
      SELECT 
        COUNT(DISTINCT m.id) AS total_matches,
        ROUND(AVG(f.first_innings_runs), 1) AS avg_score,
        ROUND(AVG(CASE WHEN m.winner = f.batting_team THEN 1.0 ELSE 0.0 END) * 100, 1) AS bat_first_win_pct
      FROM matches m
      JOIN (
        SELECT match_id, batting_team, SUM(total_runs) AS first_innings_runs 
        FROM deliveries WHERE inning = 1 GROUP BY match_id
      ) f ON m.id = f.match_id
      WHERE m.venue = '%s' AND m.winner IS NOT NULL AND m.winner != '' AND m.result != 'no result';
    ", ven_esc)
    vr_df <- dbGetQuery(con, q_vr)
    if (nrow(vr_df) > 0) {
      venue_report <- list(
        venue = venue_filter,
        matches = as.integer(vr_df$total_matches[1]),
        avg_first_innings_score = as.numeric(vr_df$avg_score[1]),
        bat_first_win_pct = as.numeric(vr_df$bat_first_win_pct[1])
      )
    }
  }

  # Opponent general analytics if requested
  opponent_report <- NULL
  if (opponent_filter != "") {
    q_or <- sprintf("
      SELECT 
        COUNT(*) AS total_matches,
        SUM(CASE WHEN winner = '%s' THEN 1 ELSE 0 END) AS opp_wins
      FROM matches
      WHERE (team1 = '%s' OR team2 = '%s') AND winner IS NOT NULL AND winner != '' AND result != 'no result';
    ", opp_esc, opp_esc, opp_esc)
    or_df <- dbGetQuery(con, q_or)
    if (nrow(or_df) > 0) {
      m_opp <- as.integer(or_df$total_matches[1])
      w_opp <- as.integer(or_df$opp_wins[1])
      opponent_report <- list(
        opponent = opponent_filter,
        matches = m_opp,
        all_time_win_pct = if (m_opp > 0) round((w_opp / m_opp) * 100, 1) else 0.0
      )
    }
  }

  # Squad Balance Suitability Score (0-100)
  # Derived transparently:
  # Batting depth: 25 pts (min 2 batsmen + batting options)
  # Bowling options: 30 pts (min 5 bowlers + depth)
  # All-rounders: 20 pts (all-round flexibility)
  # Experience: 25 pts (total verified matches played)
  score_bat <- min(25, round((batsmen_count / 5) * 25, 1))
  score_bowl <- min(30, round((bowlers_count / 6) * 30, 1))
  score_ar <- min(20, round((all_rounders_count / 3) * 20, 1))
  total_matches_sq <- sum(sapply(player_details, function(x) x$matches))
  score_exp <- min(25, round((total_matches_sq / 1200) * 25, 1))
  squad_balance_score <- round(score_bat + score_bowl + score_ar + score_exp, 1)

  balance_breakdown <- list(
    score = squad_balance_score,
    rating = if (squad_balance_score >= 85) "Exceptional Balance" else if (squad_balance_score >= 70) "Strong Squad Balance" else "Moderate Balance",
    components = list(
      batting_depth = list(score = score_bat, max = 25, label = sprintf("%d batsmen", batsmen_count)),
      bowling_options = list(score = score_bowl, max = 30, label = sprintf("%d bowlers", bowlers_count)),
      all_rounder_coverage = list(score = score_ar, max = 20, label = sprintf("%d all-rounders", all_rounders_count)),
      collective_experience = list(score = score_exp, max = 25, label = sprintf("%d career matches across XI", total_matches_sq))
    ),
    formula_note = "Suitability indicator based on squad composition balance and historical experience. Not a win probability."
  )

  # Descriptive Optional Custom Score: Unweighted Average of Individual Win Pct (explicitly documented)
  all_indiv_pcts <- sapply(player_breakdown_list, function(x) x$win_percentage)
  nonzero_pcts <- all_indiv_pcts[all_indiv_pcts > 0]
  desc_avg_all <- if (length(all_indiv_pcts) > 0) round(mean(all_indiv_pcts), 1) else 0.0
  desc_avg_nonzero <- if (length(nonzero_pcts) > 0) round(mean(nonzero_pcts), 1) else 0.0

  ret_val <- list(
    status = "success",
    lineup = list(
      total_players = 11,
      batsmen = batsmen_count,
      all_rounders = all_rounders_count,
      bowlers = bowlers_count,
      players = player_details
    ),
    filters = list(
      venue = if (venue_filter != "") venue_filter else "None",
      opponent = if (opponent_filter != "") opponent_filter else "None"
    ),
    squad_balance = balance_breakdown,
    venue_report = venue_report,
    opponent_report = opponent_report,
    venue_player_stats = venue_player_stats,
    opponent_player_stats = opp_player_stats,
    method_a_exact_xi = list(
      available = exact_available,
      summary = exact_summary,
      message = if (exact_available) "Found exact historical fixtures where all 11 selected players featured together for the same franchise team." else "Insufficient historical matches with this exact 11-player lineup playing together for a single team in official IPL records."
    ),
    method_b_aggregate_history = list(
      qualifying_matches = nrow(co_qualifying),
      min_teammates_threshold = 3,
      wins = co_w,
      losses = co_l,
      no_results = co_nr,
      win_percentage = if (has_co) co_win_pct else NA,
      formula = "wins / (wins + losses) * 100 [distinct team fixtures involving >= 3 selected players together]",
      note = "Historical team record across matches involving combinations of selected teammates — not the record of the exact selected XI unless all 11 were verified together."
    ),
    individual_contributions = player_breakdown_list,
    descriptive_scores = list(
      mean_individual_rate = desc_avg_all,
      mean_nonzero_rate = desc_avg_nonzero,
      note = "Descriptive unweighted average of individual player historical win percentages. Provided strictly as an exploratory indicator; never used as a team win probability."
    ),
    methodology_statement = list(
      chosen_method = if (exact_available) "Method A (Exact Historical Playing XI)" else "Method B (Franchise Core Fixture History)",
      sample_size_assessment = if (exact_available) sprintf("%d matches with exact lineup", nrow(exact_df)) else sprintf("%d distinct qualifying franchise matches with selected teammate combinations", nrow(co_qualifying)),
      association_vs_causation = "Historical win rate represents retrospective team performance in fixtures where these cricketers played; it does not constitute a guaranteed future win probability. Ground conditions, opponents, toss, and game situations significantly impact real-time outcomes.",
      data_scope = "1,095 matches across 17 IPL seasons (2008–2024), 260,920 deliveries in official SQLite database."
    )
  )
  
  dbDisconnect(con)
  return(ret_val)
}

# ------------------------------------------------------------------------------
# 15. Probability & Statistics Analytics Endpoint
# ------------------------------------------------------------------------------
#* Comprehensive probability distributions, correlations, tests, and team venue heatmaps
#* @get /api/probability-stats
#* @serializer json
#* @param season:character Optional season filter
#* @param team:character Optional team filter
#* @param venue:character Optional venue filter
#* @param match_type:character Optional match type filter
#* @param role_context:character Optional 'bat_first' or 'chasing' filter
function(res, season = "", team = "", venue = "", match_type = "", role_context = "") {
  con <- get_con()
  sql_esc <- function(s) gsub("'", "''", s)
  
  sea <- trimws(as.character(season))
  tm <- trimws(as.character(team))
  ven <- trimws(as.character(venue))
  mt <- trimws(as.character(match_type))
  rc <- tolower(trimws(as.character(role_context)))
  
  # Build filter clauses for matches
  m_where <- "WHERE m.winner IS NOT NULL AND m.winner != '' AND m.result != 'no result'"
  if (sea != "" && sea != "All") m_where <- paste0(m_where, sprintf(" AND m.season = '%s'", sql_esc(sea)))
  if (tm != "" && tm != "All") m_where <- paste0(m_where, sprintf(" AND (m.team1 = '%s' OR m.team2 = '%s')", sql_esc(tm), sql_esc(tm)))
  if (ven != "" && ven != "All") m_where <- paste0(m_where, sprintf(" AND m.venue = '%s'", sql_esc(ven)))
  if (mt != "" && mt != "All") m_where <- paste0(m_where, sprintf(" AND m.match_type = '%s'", sql_esc(mt)))
  
  # 1. First Innings Scores and Outcomes
  q_scores <- sprintf("
    SELECT 
      m.id,
      m.season,
      m.venue,
      m.match_type,
      m.winner,
      f.batting_team AS first_batting_team,
      f.score AS first_innings_score,
      CASE WHEN m.winner = f.batting_team THEN 1 ELSE 0 END AS bat_first_won
    FROM matches m
    JOIN (
      SELECT match_id, batting_team, SUM(total_runs) AS score
      FROM deliveries
      WHERE inning = 1
      GROUP BY match_id
    ) f ON m.id = f.match_id
    %s;
  ", m_where)
  scores_df <- dbGetQuery(con, q_scores)
  
  # 2. Batting First vs Chasing by Team (within current filters)
  q_bat_chase <- sprintf("
    SELECT 
      team,
      SUM(CASE WHEN role = 'bat_first' THEN 1 ELSE 0 END) AS bat_first_matches,
      SUM(CASE WHEN role = 'bat_first' AND won = 1 THEN 1 ELSE 0 END) AS bat_first_wins,
      SUM(CASE WHEN role = 'chase' THEN 1 ELSE 0 END) AS chase_matches,
      SUM(CASE WHEN role = 'chase' AND won = 1 THEN 1 ELSE 0 END) AS chase_wins
    FROM (
      SELECT 
        f.batting_team AS team,
        'bat_first' AS role,
        CASE WHEN m.winner = f.batting_team THEN 1 ELSE 0 END AS won
      FROM matches m
      JOIN (
        SELECT match_id, batting_team FROM deliveries WHERE inning = 1 GROUP BY match_id
      ) f ON m.id = f.match_id
      %s
      UNION ALL
      SELECT 
        CASE WHEN m.team1 = f.batting_team THEN m.team2 ELSE m.team1 END AS team,
        'chase' AS role,
        CASE WHEN m.winner != f.batting_team THEN 1 ELSE 0 END AS won
      FROM matches m
      JOIN (
        SELECT match_id, batting_team FROM deliveries WHERE inning = 1 GROUP BY match_id
      ) f ON m.id = f.match_id
      %s
    )
    GROUP BY team
    HAVING (bat_first_matches + chase_matches) >= 5
    ORDER BY (bat_first_matches + chase_matches) DESC;
  ", m_where, m_where)
  bat_chase_df <- dbGetQuery(con, q_bat_chase)
  
  # 3. Team-by-Venue Matrix (Top 10 franchises x Top 8 stadiums)
  q_heatmap <- "
    SELECT 
      m.team1 AS team,
      m.venue,
      COUNT(*) AS matches,
      SUM(CASE WHEN m.winner = m.team1 THEN 1 ELSE 0 END) AS wins,
      ROUND(AVG(f.score), 1) AS avg_score
    FROM matches m
    JOIN (
      SELECT match_id, SUM(total_runs) AS score FROM deliveries WHERE inning = 1 GROUP BY match_id
    ) f ON m.id = f.match_id
    WHERE m.winner IS NOT NULL AND m.winner != '' AND m.result != 'no result'
    GROUP BY m.team1, m.venue
    UNION ALL
    SELECT 
      m.team2 AS team,
      m.venue,
      COUNT(*) AS matches,
      SUM(CASE WHEN m.winner = m.team2 THEN 1 ELSE 0 END) AS wins,
      ROUND(AVG(f.score), 1) AS avg_score
    FROM matches m
    JOIN (
      SELECT match_id, SUM(total_runs) AS score FROM deliveries WHERE inning = 1 GROUP BY match_id
    ) f ON m.id = f.match_id
    WHERE m.winner IS NOT NULL AND m.winner != '' AND m.result != 'no result'
    GROUP BY m.team2, m.venue;
  "
  heatmap_raw <- dbGetQuery(con, q_heatmap)
  
  # Filter choices for dropdowns
  seasons_all <- dbGetQuery(con, "SELECT DISTINCT season FROM matches ORDER BY season DESC;")$season
  teams_all <- dbGetQuery(con, "SELECT DISTINCT team1 AS t FROM matches ORDER BY t;")$t
  venues_all <- dbGetQuery(con, "SELECT venue, COUNT(*) as cnt FROM matches GROUP BY venue HAVING cnt >= 10 ORDER BY cnt DESC;")$venue
  match_types_all <- dbGetQuery(con, "SELECT DISTINCT match_type FROM matches WHERE match_type IS NOT NULL ORDER BY match_type;")$match_type
  
  dbDisconnect(con)
  
  # Summary Statistical Calculations on first innings scores
  n_matches <- nrow(scores_df)
  all_scores <- if (n_matches > 0) as.numeric(scores_df$first_innings_score) else numeric(0)
  all_won <- if (n_matches > 0) as.numeric(scores_df$bat_first_won) else numeric(0)
  
  avg_score <- if (n_matches > 0) round(mean(all_scores), 1) else 0.0
  median_score <- if (n_matches > 0) as.integer(round(median(all_scores))) else 0
  sd_score <- if (n_matches > 1) round(sd(all_scores), 1) else 0.0
  var_score <- if (n_matches > 1) round(var(all_scores), 1) else 0.0
  min_score <- if (n_matches > 0) min(all_scores) else 0
  max_score <- if (n_matches > 0) max(all_scores) else 0
  
  # Correlations between first-innings score and batting-first victory
  pearson_r <- if (n_matches > 2) round(cor(all_scores, all_won, method = "pearson"), 3) else 0.0
  spearman_rho <- if (n_matches > 2) round(cor(all_scores, all_won, method = "spearman"), 3) else 0.0
  
  # Selected Team win percentage under filters
  selected_team_stats <- NULL
  if (tm != "" && tm != "All") {
    t_matches <- sum(scores_df$first_batting_team == tm | scores_df$bat_first_won == (scores_df$first_batting_team != tm))
    t_wins <- sum(scores_df$winner == tm)
    t_pct <- if (n_matches > 0) round((t_wins / n_matches) * 100, 1) else 0.0
    
    # 95% Wilson score confidence interval for binomial proportion
    z <- 1.96
    denom <- 1 + (z^2 / n_matches)
    p_hat <- t_wins / n_matches
    center <- (p_hat + (z^2 / (2 * n_matches))) / denom
    margin <- (z * sqrt((p_hat * (1 - p_hat) / n_matches) + (z^2 / (4 * n_matches^2)))) / denom
    ci_lower <- max(0, round((center - margin) * 100, 1))
    ci_upper <- min(100, round((center + margin) * 100, 1))
    
    selected_team_stats <- list(
      team = tm,
      matches = n_matches,
      wins = t_wins,
      losses = n_matches - t_wins,
      win_percentage = t_pct,
      ci_95 = list(lower = ci_lower, upper = ci_upper)
    )
  }
  
  # Graph A: Score Distribution Histogram Bands (width = 15 runs)
  bands_def <- list(
    list(label = "< 120", min = 0, max = 119),
    list(label = "120-139", min = 120, max = 139),
    list(label = "140-154", min = 140, max = 154),
    list(label = "155-169", min = 155, max = 169),
    list(label = "170-184", min = 170, max = 184),
    list(label = "185-199", min = 185, max = 199),
    list(label = "200-214", min = 200, max = 214),
    list(label = "215+", min = 215, max = 999)
  )
  
  histogram_data <- list()
  win_by_band_data <- list()
  for (b in bands_def) {
    in_b <- scores_df[scores_df$first_innings_score >= b$min & scores_df$first_innings_score <= b$max, ]
    b_count <- nrow(in_b)
    b_wins <- sum(in_b$bat_first_won == 1)
    b_win_pct <- if (b_count > 0) round((b_wins / b_count) * 100, 1) else 0.0
    
    # 95% CI for win rate in band
    b_ci_low <- 0.0
    b_ci_up <- 0.0
    if (b_count >= 5) {
      z <- 1.96
      p_b <- b_wins / b_count
      d_b <- 1 + (z^2 / b_count)
      c_b <- (p_b + (z^2 / (2 * b_count))) / d_b
      m_b <- (z * sqrt((p_b * (1 - p_b) / b_count) + (z^2 / (4 * b_count^2)))) / d_b
      b_ci_low <- max(0, round((c_b - m_b) * 100, 1))
      b_ci_up <- min(100, round((c_b + m_b) * 100, 1))
    }
    
    histogram_data[[length(histogram_data) + 1]] <- list(
      band = b$label,
      count = b_count,
      pct_of_total = if (n_matches > 0) round((b_count / n_matches) * 100, 1) else 0.0
    )
    
    win_by_band_data[[length(win_by_band_data) + 1]] <- list(
      band = b$label,
      qualifying_matches = b_count,
      bat_first_wins = b_wins,
      historical_win_pct = b_win_pct,
      ci_95_lower = b_ci_low,
      ci_95_upper = b_ci_up
    )
  }
  
  # Graph C: Batting First vs Chasing Comparison Table/List
  bat_vs_chase_list <- list()
  if (nrow(bat_chase_df) > 0) {
    for (i in 1:nrow(bat_chase_df)) {
      tm_name <- as.character(bat_chase_df$team[i])
      bf_m <- as.integer(bat_chase_df$bat_first_matches[i])
      bf_w <- as.integer(bat_chase_df$bat_first_wins[i])
      ch_m <- as.integer(bat_chase_df$chase_matches[i])
      ch_w <- as.integer(bat_chase_df$chase_wins[i])
      
      bat_vs_chase_list[[length(bat_vs_chase_list) + 1]] <- list(
        team = tm_name,
        bat_first = list(
          matches = bf_m,
          wins = bf_w,
          win_pct = if (bf_m > 0) round((bf_w / bf_m) * 100, 1) else 0.0
        ),
        chasing = list(
          matches = ch_m,
          wins = ch_w,
          win_pct = if (ch_m > 0) round((ch_w / ch_m) * 100, 1) else 0.0
        ),
        total_matches = bf_m + ch_m
      )
    }
  }

  # Graph E: Team-by-Venue Heatmap Data Aggregation
  top_venues <- head(venues_all, 8)
  top_teams <- c("Mumbai Indians", "Chennai Super Kings", "Kolkata Knight Riders", "Royal Challengers Bengaluru", "Rajasthan Royals", "Delhi Capitals", "Punjab Kings", "Sunrisers Hyderabad")
  
  venue_heatmap_cells <- list()
  for (t_name in top_teams) {
    for (v_name in top_venues) {
      cell_sub <- heatmap_raw[heatmap_raw$team == t_name & heatmap_raw$venue == v_name, ]
      c_matches <- sum(as.integer(cell_sub$matches))
      c_wins <- sum(as.integer(cell_sub$wins))
      c_win_pct <- if (c_matches > 0) round((c_wins / c_matches) * 100, 1) else 0.0
      c_avg_score <- if (c_matches > 0) round(mean(cell_sub$avg_score, na.rm = TRUE), 1) else 0.0
      
      venue_heatmap_cells[[length(venue_heatmap_cells) + 1]] <- list(
        team = t_name,
        venue = v_name,
        matches = c_matches,
        wins = c_wins,
        win_pct = c_win_pct,
        avg_score = c_avg_score,
        low_sample = (c_matches < 5)
      )
    }
  }
  
  # Graph F: Confidence Intervals on Win Rate for Active Teams
  team_ci_list <- list()
  if (nrow(bat_chase_df) > 0) {
    for (i in 1:nrow(bat_chase_df)) {
      tm_name <- as.character(bat_chase_df$team[i])
      tot_m <- as.integer(bat_chase_df$bat_first_matches[i]) + as.integer(bat_chase_df$chase_matches[i])
      tot_w <- as.integer(bat_chase_df$bat_first_wins[i]) + as.integer(bat_chase_df$chase_wins[i])
      p_h <- tot_w / tot_m
      z <- 1.96
      d_m <- 1 + (z^2 / tot_m)
      c_m <- (p_h + (z^2 / (2 * tot_m))) / d_m
      m_err <- (z * sqrt((p_h * (1 - p_h) / tot_m) + (z^2 / (4 * tot_m^2)))) / d_m
      
      team_ci_list[[length(team_ci_list) + 1]] <- list(
        team = tm_name,
        matches = tot_m,
        wins = tot_w,
        win_percentage = round(p_h * 100, 1),
        ci_lower = max(0, round((c_m - m_err) * 100, 1)),
        ci_upper = min(100, round((c_m + m_err) * 100, 1))
      )
    }
  }

  list(
    status = "success",
    filters_applied = list(
      season = if (sea != "") sea else "All",
      team = if (tm != "") tm else "All",
      venue = if (ven != "") ven else "All",
      match_type = if (mt != "") mt else "All"
    ),
    available_filters = list(
      seasons = seasons_all,
      teams = teams_all,
      venues = venues_all,
      match_types = match_types_all
    ),
    summary_cards = list(
      unique_matches = n_matches,
      avg_first_innings_score = avg_score,
      median_first_innings_score = median_score,
      std_dev_first_innings_score = sd_score,
      variance_score = var_score,
      min_score = min_score,
      max_score = max_score,
      correlations = list(
        pearson_score_vs_win = pearson_r,
        spearman_score_vs_win = spearman_rho
      ),
      selected_team = selected_team_stats
    ),
    graph_a_score_histogram = histogram_data,
    graph_b_win_by_score_band = win_by_band_data,
    graph_c_bat_vs_chase = bat_vs_chase_list,
    graph_e_venue_heatmap = list(
      teams = top_teams,
      venues = top_venues,
      cells = venue_heatmap_cells
    ),
    graph_f_confidence_intervals = team_ci_list,
    methodology = list(
      score_definition = "First-innings 20-over totals summed from ball-by-ball deliveries table.",
      confidence_interval_method = "Wilson score 95% binomial interval for proportion estimates.",
      correlation_note = "Pearson measuring linear covariance; Spearman measuring monotonic rank correlation against match victory.",
      causation_warning = "Observational historical metrics: higher totals correlate with match victory but do not constitute guaranteed future outcomes."
    )
  )
}

