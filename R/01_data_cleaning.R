# ==============================================================================
# File: 01_data_cleaning.R
# Project: A Comparative Study of ML Models for Explainable IPL Match Outcome Prediction
# Description: Data inspection, missing value handling, franchise/city standardization
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

cat("====================================================================\n")
cat("                STEP 1: DATASET INSPECTION & CLEANING               \n")
cat("====================================================================\n\n")

# 1. Load Raw Datasets
matches_path <- "data/matches.csv"
deliveries_path <- "data/deliveries.csv"

if (!file.exists(matches_path) || !file.exists(deliveries_path)) {
  stop("Input CSV files missing in data/ directory!")
}

cat("Loading raw datasets...\n")
matches_raw <- read.csv(matches_path, stringsAsFactors = FALSE)
deliveries_raw <- read.csv(deliveries_path, stringsAsFactors = FALSE)

cat(sprintf("Matches raw: %d rows, %d columns\n", nrow(matches_raw), ncol(matches_raw)))
cat(sprintf("Deliveries raw: %d rows, %d columns\n\n", nrow(deliveries_raw), ncol(deliveries_raw)))

# 2. Inspect Column Names & Types
cat("--- Matches Schema ---\n")
print(sapply(matches_raw, class))

cat("\n--- Deliveries Schema ---\n")
print(sapply(deliveries_raw, class))

# 3. Inspect Missing Values
cat("\n--- Matches Missing Values Count ---\n")
matches_na <- sapply(matches_raw, function(x) sum(is.na(x) | x == "" | x == "NA"))
print(matches_na[matches_na > 0])

cat("\n--- Deliveries Missing Values Count ---\n")
deliveries_na <- sapply(deliveries_raw, function(x) sum(is.na(x) | x == "" | x == "NA"))
print(deliveries_na[deliveries_na > 0])

# 4. Standardize Franchise / Team Names
# IPL teams underwent rebranding and ownership changes over 2008-2024:
# - Rising Pune Supergiants -> Rising Pune Supergiant
# - Delhi Daredevils -> Delhi Capitals (renamed in 2019)
# - Kings XI Punjab -> Punjab Kings (renamed in 2021)
# - Royal Challengers Bangalore -> Royal Challengers Bengaluru (renamed in 2024)
# - Deccan Chargers -> Sunrisers Hyderabad (Hyderabad franchise continuity)

standardize_team <- function(team_vec) {
  team_vec <- trimws(team_vec)
  team_vec[team_vec == "Rising Pune Supergiants"] <- "Rising Pune Supergiant"
  team_vec[team_vec == "Delhi Daredevils"] <- "Delhi Capitals"
  team_vec[team_vec == "Kings XI Punjab"] <- "Punjab Kings"
  team_vec[team_vec == "Royal Challengers Bangalore"] <- "Royal Challengers Bengaluru"
  team_vec[team_vec == "Deccan Chargers"] <- "Sunrisers Hyderabad"
  return(team_vec)
}

matches_clean <- matches_raw
deliveries_clean <- deliveries_raw

matches_clean$team1 <- standardize_team(matches_clean$team1)
matches_clean$team2 <- standardize_team(matches_clean$team2)
matches_clean$toss_winner <- standardize_team(matches_clean$toss_winner)
matches_clean$winner <- standardize_team(matches_clean$winner)

deliveries_clean$batting_team <- standardize_team(deliveries_clean$batting_team)
deliveries_clean$bowling_team <- standardize_team(deliveries_clean$bowling_team)

# 5. Standardize Cities & Venues
# Impute missing cities for Dubai and Sharjah
matches_clean$city[is.na(matches_clean$city) | matches_clean$city == "" | matches_clean$city == "NA"] <- 
  ifelse(grepl("Dubai", matches_clean$venue[is.na(matches_clean$city) | matches_clean$city == "" | matches_clean$city == "NA"], ignore.case = TRUE), "Dubai",
  ifelse(grepl("Sharjah", matches_clean$venue[is.na(matches_clean$city) | matches_clean$city == "" | matches_clean$city == "NA"], ignore.case = TRUE), "Sharjah", "Unknown"))

# Standardize Bangalore -> Bengaluru
matches_clean$city[matches_clean$city == "Bangalore"] <- "Bengaluru"

# Standardize Dates
matches_clean$date <- as.Date(matches_clean$date)

# Sort chronologically by date and id
matches_clean <- matches_clean %>% arrange(date, id)

# 6. Summary of Cleaned Data
cat("\nCleaned Matches Distinct Teams (", length(unique(matches_clean$team1)), "):\n")
cat(paste(sort(unique(matches_clean$team1)), collapse = ", "), "\n\n")

cat("Cleaned Matches Season Breakdown:\n")
print(table(matches_clean$season))

cat("\nNo-result / Abandoned matches:\n")
abandoned <- matches_clean %>% filter(result == "no result" | is.na(winner) | winner == "")
cat(sprintf("Count: %d\n", nrow(abandoned)))

# Save Cleaned CSVs
write.csv(matches_clean, "data/matches_cleaned.csv", row.names = FALSE)
write.csv(deliveries_clean, "data/deliveries_cleaned.csv", row.names = FALSE)

cat("\nCleaned files successfully saved to data/matches_cleaned.csv and data/deliveries_cleaned.csv\n")
cat("Data cleaning completed successfully.\n")
cat("====================================================================\n\n")
