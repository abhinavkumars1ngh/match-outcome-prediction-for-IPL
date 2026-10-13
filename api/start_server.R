# ==============================================================================
# File: api/start_server.R
# Project: Explainable IPL Match Outcome Prediction
# Description: Launcher script for Plumber REST API Server (Port 8000)
# ==============================================================================

suppressPackageStartupMessages({
  library(plumber)
})

cat("====================================================================\n")
cat("          STARTING IPL MATCH OUTCOME PREDICTION API (R Plumber)      \n")
cat("====================================================================\n\n")

api_file <- "api/plumber.R"
if (!file.exists(api_file)) {
  stop(sprintf("Fatal: Plumber definition file '%s' not found!", api_file))
}

cat("Mounting API router from:", api_file, "\n")
pr <- plumb(api_file)

port <- 8000
host <- "0.0.0.0"

cat(sprintf("Listening on http://127.0.0.1:%d\n", port))
cat(sprintf("API Documentation available at: http://127.0.0.1:%d/__docs__/\n", port))
cat("Press Ctrl+C to stop the server.\n\n")

pr$run(host = host, port = port, swagger = TRUE)
