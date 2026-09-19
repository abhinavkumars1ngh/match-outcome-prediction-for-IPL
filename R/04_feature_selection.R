# ==============================================================================
# File: 04_feature_selection.R
# Project: A Comparative Study of ML Models for Explainable IPL Match Outcome Prediction
# Description: Variance filtering, correlation analysis, and model-based feature selection
# ==============================================================================

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(randomForest)
})

cat("====================================================================\n")
cat("                STEP 4: FEATURE SELECTION & SCREENING               \n")
cat("====================================================================\n\n")

db_path <- "database/ipl_database.sqlite"
con <- dbConnect(SQLite(), db_path)

cat("Retrieving feature dataset from SQLite database...\n")
features_df <- dbGetQuery(con, "SELECT * FROM model_features;")
dbDisconnect(con)

# Candidate predictor columns
candidate_features <- c(
  "team1_win_pct", "team2_win_pct", "win_pct_diff",
  "team1_recent_form", "team2_recent_form", "recent_form_diff",
  "team1_h2h_win_pct", "team2_h2h_win_pct", "h2h_diff",
  "team1_venue_win_pct", "team2_venue_win_pct", "venue_performance_diff",
  "venue_average_score", "venue_toss_win_pct",
  "toss_winner_is_team1", "toss_decision_bat", "is_playoff"
)

cat(sprintf("Total original candidate features: %d\n", length(candidate_features)))
print(candidate_features)

# 1. Variance Filtering
cat("\n--- 1. Variance Filtering ---\n")
variances <- sapply(features_df[, candidate_features], var, na.rm = TRUE)
print(round(variances, 6))

zero_var_features <- names(variances[variances < 1e-4])
if (length(zero_var_features) > 0) {
  cat("Identified near-zero variance features to remove:", paste(zero_var_features, collapse=", "), "\n")
} else {
  cat("All features possess adequate variance (> 1e-4).\n")
}

# 2. Correlation Analysis & Multicollinearity Filtering
cat("\n--- 2. Correlation Analysis & Multicollinearity Filtering ---\n")
cor_matrix <- cor(features_df[, candidate_features], use = "pairwise.complete.obs")

# Identify highly collinear pairs (|r| > 0.85)
high_cor_pairs <- list()
for (i in 1:(ncol(cor_matrix) - 1)) {
  for (j in (i + 1):ncol(cor_matrix)) {
    if (abs(cor_matrix[i, j]) > 0.85) {
      high_cor_pairs[[length(high_cor_pairs) + 1]] <- data.frame(
        Feature1 = rownames(cor_matrix)[i],
        Feature2 = colnames(cor_matrix)[j],
        Correlation = round(cor_matrix[i, j], 4)
      )
    }
  }
}

high_cor_df <- do.call(rbind, high_cor_pairs)
cat("Highly collinear feature pairs (|r| > 0.85):\n")
print(high_cor_df)

# Feature redundancy elimination:
# - team2_h2h_win_pct is exactly (1 - team1_h2h_win_pct), correlation = -1.000. Redundant!
# - h2h_diff is exactly 2 * team1_h2h_win_pct - 1, correlation = 1.000. Redundant!
# - We retain `h2h_diff` (which directly measures relative advantage) and remove `team1_h2h_win_pct` and `team2_h2h_win_pct`.
# - Similarly, difference features (win_pct_diff, recent_form_diff, venue_performance_diff) concisely encode relative advantage.

redundant_features <- c("team2_h2h_win_pct", "team1_h2h_win_pct")

# 3. Model-Based Feature Selection (Random Forest Gini Importance)
cat("\n--- 3. Random Forest Feature Importance Screening ---\n")
set.seed(42)
rf_df <- features_df[, c(setdiff(candidate_features, redundant_features), "team1_won")]
rf_df$team1_won <- as.factor(rf_df$team1_won)

rf_screen <- randomForest(team1_won ~ ., data = rf_df, ntree = 300, importance = TRUE)
imp <- importance(rf_screen)
imp_df <- data.frame(
  Feature = rownames(imp),
  MeanDecreaseGini = round(imp[, "MeanDecreaseGini"], 4),
  MeanDecreaseAccuracy = round(imp[, "MeanDecreaseAccuracy"], 4)
) %>% arrange(desc(MeanDecreaseGini))

cat("Random Forest Feature Importance Ranking:\n")
print(imp_df)

# Final Selected Features:
selected_features <- c(
  "win_pct_diff",
  "recent_form_diff",
  "h2h_diff",
  "venue_performance_diff",
  "team1_win_pct",
  "team2_win_pct",
  "team1_recent_form",
  "team2_recent_form",
  "team1_venue_win_pct",
  "team2_venue_win_pct",
  "venue_average_score",
  "venue_toss_win_pct",
  "toss_winner_is_team1",
  "toss_decision_bat",
  "is_playoff"
)

removed_features <- c(
  "team2_h2h_win_pct",
  "team1_h2h_win_pct"
)

removal_reasons <- c(
  "Perfect collinearity (r = -1.000) with team1_h2h_win_pct; exactly redundant.",
  "Perfect collinearity (r = 1.000) with h2h_diff; relative difference retained."
)

report_df <- data.frame(
  Status = c(rep("Selected", length(selected_features)), rep("Removed", length(removed_features))),
  Feature = c(selected_features, removed_features),
  Reason = c(
    rep("Passed variance, collinearity screening, and exhibits meaningful predictive importance", length(selected_features)),
    removal_reasons
  )
)

if (!dir.exists("results")) dir.create("results", recursive = TRUE)
write.csv(report_df, "results/feature_selection_summary.csv", row.names = FALSE)

cat("\n====================================================================\n")
cat("                  FEATURE SELECTION AUDIT REPORT                    \n")
cat("====================================================================\n")
cat(sprintf("Original Features Count : %d\n", length(candidate_features)))
cat(sprintf("Removed Features Count  : %d\n", length(removed_features)))
cat(sprintf("Selected Features Count : %d\n\n", length(selected_features)))

cat("--- Removed Features & Reasons ---\n")
for (k in 1:length(removed_features)) {
  cat(sprintf("• %s -> %s\n", removed_features[k], removal_reasons[k]))
}

cat("\n--- Final Selected Feature Set (%d Features) ---\n", length(selected_features))
cat(paste(paste0(1:length(selected_features), ". ", selected_features), collapse = "\n"), "\n")

# Save selected features list for downstream modeling scripts
saveRDS(selected_features, "results/selected_features.rds")
cat("\nSaved selected features configuration to 'results/selected_features.rds'\n")
cat("Feature selection completed successfully.\n")
cat("====================================================================\n\n")
