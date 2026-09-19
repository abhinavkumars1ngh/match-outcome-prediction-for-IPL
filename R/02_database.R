# ==============================================================================
# File: 02_database.R
# Project: A Comparative Study of ML Models for Explainable IPL Match Outcome Prediction
# Description: SQLite database creation, indexing, and data retrieval using DBI/RSQLite
# ==============================================================================

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
})

cat("====================================================================\n")
cat("                STEP 2: SQLITE DATABASE SETUP & QUERIES             \n")
cat("====================================================================\n\n")

db_dir <- "database"
if (!dir.exists(db_dir)) dir.create(db_dir, recursive = TRUE)
db_path <- file.path(db_dir, "ipl_database.sqlite")

# 1. Connect to SQLite Database
cat(sprintf("Connecting to SQLite database at: %s\n", db_path))
con <- dbConnect(SQLite(), db_path)

# 2. Load Cleaned Datasets
cat("Reading cleaned CSV datasets for database ingestion...\n")
matches_clean <- read.csv("data/matches_cleaned.csv", stringsAsFactors = FALSE)
deliveries_clean <- read.csv("data/deliveries_cleaned.csv", stringsAsFactors = FALSE)

# 3. Write Tables to SQLite
cat("Writing 'matches' table to SQLite...\n")
dbWriteTable(con, "matches", matches_clean, overwrite = TRUE)

cat("Writing 'deliveries' table to SQLite (260k+ records)...\n")
dbWriteTable(con, "deliveries", deliveries_clean, overwrite = TRUE)

cat("\nDatabase Tables Created:\n")
print(dbListTables(con))

# 4. Create Performance Indexes
cat("\nCreating database indexes for optimized query performance...\n")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_matches_id ON matches(id);")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_matches_winner ON matches(winner);")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_matches_season ON matches(season);")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_matches_venue ON matches(venue);")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_matches_teams ON matches(team1, team2);")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_deliveries_match_id ON deliveries(match_id);")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_deliveries_batter ON deliveries(batter);")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_deliveries_bowler ON deliveries(bowler);")
cat("Indexes successfully created.\n")

# 5. Execute Demonstration SQL Queries (Rubric: SQLite connectivity & data retrieval using R)

cat("\n--------------------------------------------------------------------\n")
cat("SQL QUERY 1: Total Matches and Wins by Team (All Seasons)\n")
cat("--------------------------------------------------------------------\n")
query1 <- "
SELECT 
    winner AS Team,
    COUNT(*) AS Wins
FROM matches
WHERE winner IS NOT NULL AND winner != '' AND winner != 'NA'
GROUP BY winner
ORDER BY Wins DESC;
"
cat(query1, "\n")
res1 <- dbGetQuery(con, query1)
print(res1)

cat("\n--------------------------------------------------------------------\n")
cat("SQL QUERY 2: Toss Win vs Match Win Conversion Rate\n")
cat("--------------------------------------------------------------------\n")
query2 <- "
SELECT 
    COUNT(*) AS total_matches,
    SUM(CASE WHEN toss_winner = winner THEN 1 ELSE 0 END) AS toss_and_match_winner,
    ROUND(AVG(CASE WHEN toss_winner = winner THEN 1.0 ELSE 0.0 END) * 100, 2) AS toss_win_match_win_pct
FROM matches
WHERE winner IS NOT NULL AND winner != '' AND winner != 'NA';
"
cat(query2, "\n")
res2 <- dbGetQuery(con, query2)
print(res2)

cat("\n--------------------------------------------------------------------\n")
cat("SQL QUERY 3: Mumbai Indians vs Chennai Super Kings (Head-to-Head)\n")
cat("--------------------------------------------------------------------\n")
query3 <- "
SELECT 
    winner AS Match_Winner,
    COUNT(*) AS Wins,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM matches 
        WHERE (team1 IN ('Mumbai Indians', 'Chennai Super Kings')) 
          AND (team2 IN ('Mumbai Indians', 'Chennai Super Kings'))
          AND winner IS NOT NULL AND winner != ''), 2) AS Win_Percentage
FROM matches
WHERE (team1 IN ('Mumbai Indians', 'Chennai Super Kings')) 
  AND (team2 IN ('Mumbai Indians', 'Chennai Super Kings'))
  AND winner IS NOT NULL AND winner != ''
GROUP BY winner
ORDER BY Wins DESC;
"
cat(query3, "\n")
res3 <- dbGetQuery(con, query3)
print(res3)

cat("\n--------------------------------------------------------------------\n")
cat("SQL QUERY 4: Top 10 Most Hosted Venues and Chasing Win Rate\n")
cat("--------------------------------------------------------------------\n")
query4 <- "
SELECT 
    venue,
    COUNT(*) AS matches_hosted,
    SUM(CASE WHEN result = 'wickets' THEN 1 ELSE 0 END) AS chasing_wins,
    ROUND(AVG(CASE WHEN result = 'wickets' THEN 1.0 ELSE 0.0 END) * 100, 2) AS chasing_win_pct
FROM matches
WHERE result IN ('runs', 'wickets')
GROUP BY venue
ORDER BY matches_hosted DESC
LIMIT 10;
"
cat(query4, "\n")
res4 <- dbGetQuery(con, query4)
print(res4)

cat("\n--------------------------------------------------------------------\n")
cat("SQL QUERY 5: Top 10 Run Scorers in IPL History (from deliveries)\n")
cat("--------------------------------------------------------------------\n")
query5 <- "
SELECT 
    batter,
    SUM(batsman_runs) AS total_runs,
    COUNT(DISTINCT match_id) AS innings_batted,
    ROUND(SUM(batsman_runs) * 1.0 / COUNT(DISTINCT match_id), 2) AS runs_per_match
FROM deliveries
GROUP BY batter
ORDER BY total_runs DESC
LIMIT 10;
"
cat(query5, "\n")
res5 <- dbGetQuery(con, query5)
print(res5)

# Disconnect
dbDisconnect(con)
cat("\nSQLite database setup and query demonstration completed successfully.\n")
cat("====================================================================\n\n")
