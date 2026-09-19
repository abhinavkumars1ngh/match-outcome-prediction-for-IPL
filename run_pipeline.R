# ==============================================================================
# File: run_pipeline.R
# Project: A Comparative Study of ML Models for Explainable IPL Match Outcome Prediction
# Description: Master Pipeline Runner - Orchestrates all 8 stages reproducibly
# ==============================================================================

cat("####################################################################\n")
cat("#                                                                  #\n")
cat("#   EXPLAINABLE IPL MATCH OUTCOME PREDICTION PIPELINE (R + SQLite)  #\n")
cat("#                                                                  #\n")
cat("####################################################################\n\n")

start_time <- Sys.time()

stages <- c(
  "R/01_data_cleaning.R",
  "R/02_database.R",
  "R/03_feature_engineering.R",
  "R/04_feature_selection.R",
  "R/05_models.R",
  "R/06_hyperparameter_tuning.R",
  "R/07_evaluation.R",
  "R/08_visualizations.R"
)

for (stage in stages) {
  if (!file.exists(stage)) {
    stop(sprintf("Fatal: Stage script '%s' not found!", stage))
  }
  cat(sprintf("\n>>> Executing Stage: %s <<<\n", stage))
  source(stage)
}

end_time <- Sys.time()
elapsed <- round(as.numeric(difftime(end_time, start_time, units = "secs")), 2)

cat("\n####################################################################\n")
cat(sprintf("#   PIPELINE EXECUTION COMPLETE IN %.2f SECONDS                     #\n", elapsed))
cat("#   All models, SQLite tables, metrics, and plots generated!       #\n")
cat("####################################################################\n")
