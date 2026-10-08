# ============================================================
# IPL MASTER SHEET
# IPL 2008-2024
#
# DATASETS:
# 1. matches.csv
# 2. deliveries.csv
# 3. ball_by_ball_data.csv
#
# OUTPUT:
# 1. IPL_Master_Sheet.duckdb
# 2. IPL_Master_Sheet.csv
#
# FINAL TABLE:
# ipl_master_sheet
# ============================================================


# ============================================================
# 1. PACKAGES
# ============================================================

library(DBI)
library(duckdb)


# ============================================================
# 2. FILE PATHS
# ============================================================

matches_file <-
  "C:/Users/mukul/OneDrive/Desktop/Downloads/matches.csv"

deliveries_file <-
  "C:/Users/mukul/OneDrive/Desktop/Downloads/deliveries.csv"

ultimate_file <-
  "C:/Users/mukul/OneDrive/Desktop/Downloads/ball_by_ball_data.csv"


# ============================================================
# 3. OUTPUT PATHS
# ============================================================

database_file <-
  "C:/Users/mukul/OneDrive/Desktop/Downloads/IPL_Master_Sheet.duckdb"

csv_file <-
  "C:/Users/mukul/OneDrive/Desktop/Downloads/IPL_Master_Sheet.csv"


# ============================================================
# 4. CHECK FILES
# ============================================================

cat("\n========================================\n")
cat("CHECKING FILES\n")
cat("========================================\n")

if (!file.exists(matches_file)) {
  stop("matches.csv not found.")
}

if (!file.exists(deliveries_file)) {
  stop("deliveries.csv not found.")
}

if (!file.exists(ultimate_file)) {
  stop("ball_by_ball_data.csv not found.")
}

cat("matches.csv      : FOUND\n")
cat("deliveries.csv   : FOUND\n")
cat("Ultimate dataset : FOUND\n")


# ============================================================
# 5. CONNECT TO DUCKDB
# ============================================================

con <- dbConnect(
  duckdb(),
  dbdir = database_file
)

cat("\nDuckDB connected.\n")


# ============================================================
# 6. CREATE IPL MATCH TABLE
# ============================================================
#
# IMPORTANT SEASON MAPPING:
#
# 2007/08 -> 2008
# 2009    -> 2009
# 2009/10 -> 2010
# 2020/21 -> 2020
#
# This prevents IPL 2008 from being dropped.
# ============================================================

cat("\nCreating matches_ipl...\n")

dbExecute(
  con,
  paste0(
    "
    CREATE OR REPLACE TEMP TABLE matches_ipl AS

    SELECT
        *,
        CASE

            WHEN season = '2007/08'
                THEN 2008

            WHEN season = '2009/10'
                THEN 2010

            WHEN season = '2020/21'
                THEN 2020

            ELSE TRY_CAST(season AS INTEGER)

        END AS project_season

    FROM read_csv_auto(
        '", matches_file, "',
        all_varchar = true
    )

    WHERE season IN (

        '2007/08',
        '2009',
        '2009/10',
        '2011',
        '2012',
        '2013',
        '2014',
        '2015',
        '2016',
        '2017',
        '2018',
        '2019',
        '2020/21',
        '2021',
        '2022',
        '2023',
        '2024'

    )
    "
  )
)

cat("matches_ipl created.\n")


# ============================================================
# 7. MATCH COUNT BY SEASON
# ============================================================

matches_by_season <- dbGetQuery(
  con,
  "
  SELECT
      project_season,
      COUNT(DISTINCT id) AS matches

  FROM matches_ipl

  GROUP BY project_season

  ORDER BY project_season
  "
)

cat("\n========================================\n")
cat("MATCHES BY SEASON\n")
cat("========================================\n")

print(
  matches_by_season,
  row.names = FALSE
)


# ============================================================
# 8. CREATE IPL DELIVERY TABLE
# ============================================================

cat("\nCreating deliveries_ipl...\n")

dbExecute(
  con,
  paste0(
    "
    CREATE OR REPLACE TEMP TABLE deliveries_ipl AS

    SELECT
        d.*,
        m.project_season

    FROM read_csv_auto(
        '", deliveries_file, "',
        all_varchar = true
    ) d

    INNER JOIN matches_ipl m

        ON CAST(d.match_id AS VARCHAR)
        =
        CAST(m.id AS VARCHAR)
    "
  )
)

cat("deliveries_ipl created.\n")


# ============================================================
# 9. CHECK 2008
# ============================================================

check_2008 <- dbGetQuery(
  con,
  "
  SELECT

      project_season,

      COUNT(DISTINCT match_id) AS matches,

      COUNT(*) AS balls

  FROM deliveries_ipl

  WHERE project_season = 2008

  GROUP BY project_season
  "
)

cat("\n========================================\n")
cat("2008 CHECK\n")
cat("========================================\n")

print(
  check_2008,
  row.names = FALSE
)


# ============================================================
# 10. LOAD ULTIMATE DATASET
# ============================================================

cat("\nLoading Ultimate dataset...\n")

dbExecute(
  con,
  paste0(
    "
    CREATE OR REPLACE TEMP TABLE ultimate_raw AS

    SELECT *

    FROM read_csv_auto(
        '", ultimate_file, "',
        all_varchar = true
    )
    "
  )
)

cat("Ultimate dataset loaded.\n")


# ============================================================
# 11. CREATE ULTIMATE IPL TABLE
# ============================================================

cat("\nCreating ultimate_ipl...\n")

dbExecute(
  con,
  "
  CREATE OR REPLACE TEMP TABLE ultimate_ipl AS

  SELECT *

  FROM ultimate_raw

  WHERE

      event = 'Indian Premier League'

      OR

      type = 'Fran(IPL)'
  "
)

ultimate_match_count <- dbGetQuery(
  con,
  "
  SELECT
      COUNT(DISTINCT match_id) AS matches

  FROM ultimate_ipl
  "
)

cat("\nUltimate IPL matches:\n")

print(
  ultimate_match_count,
  row.names = FALSE
)


# ============================================================
# 12. TEAM CLEANING FUNCTION
# ============================================================

team_clean_sql <- function(x) {
  
  paste0(
    "
    CASE

        WHEN ", x, " IN (
            'Delhi Daredevils',
            'Delhi Capitals'
        )
        THEN 'Delhi Capitals'


        WHEN ", x, " IN (
            'Kings XI Punjab',
            'Punjab Kings'
        )
        THEN 'Punjab Kings'


        WHEN ", x, " IN (
            'Royal Challengers Bangalore',
            'Royal Challengers Bengaluru'
        )
        THEN 'Royal Challengers Bangalore'


        WHEN ", x, " IN (
            'Rising Pune Supergiant',
            'Rising Pune Supergiants'
        )
        THEN 'Rising Pune Supergiant'


        ELSE ", x, "

    END
    "
  )
}


# ============================================================
# 13. ULTIMATE MATCH MAP
# ============================================================

cat("\nCreating Ultimate match map...\n")

dbExecute(
  con,
  "
  CREATE OR REPLACE TEMP TABLE ultimate_match_map_raw AS

  SELECT DISTINCT

      match_id AS ultimate_match_id,

      TRY_CAST(start_date AS DATE) AS match_date,

      batting_team AS team

  FROM ultimate_ipl


  UNION


  SELECT DISTINCT

      match_id AS ultimate_match_id,

      TRY_CAST(start_date AS DATE) AS match_date,

      bowling_team AS team

  FROM ultimate_ipl
  "
)


# ============================================================
# 14. GET TWO TEAMS PER ULTIMATE MATCH
# ============================================================

dbExecute(
  con,
  "
  CREATE OR REPLACE TEMP TABLE ultimate_match_map AS

  SELECT

      ultimate_match_id,

      match_date,

      MIN(team) AS team_a,

      MAX(team) AS team_b

  FROM ultimate_match_map_raw

  GROUP BY

      ultimate_match_id,

      match_date
  "
)


# ============================================================
# 15. CLEAN ULTIMATE TEAM NAMES
# ============================================================

dbExecute(
  con,
  paste0(
    "
    CREATE OR REPLACE TEMP TABLE
    ultimate_match_map_clean AS

    SELECT

        ultimate_match_id,

        match_date,

        ",
    team_clean_sql("team_a"),
    " AS team_a,

        ",
    team_clean_sql("team_b"),
    " AS team_b

    FROM ultimate_match_map
    "
  )
)


# ============================================================
# 16. PATRICK MATCH MAP
# ============================================================

dbExecute(
  con,
  "
  CREATE OR REPLACE TEMP TABLE
  patrick_match_map_raw AS

  SELECT

      id AS patrick_match_id,

      TRY_CAST(date AS DATE) AS match_date,

      team1,

      team2

  FROM matches_ipl
  "
)


# ============================================================
# 17. STANDARDIZE PATRICK TEAM ORDER
# ============================================================

dbExecute(
  con,
  paste0(
    "
    CREATE OR REPLACE TEMP TABLE
    patrick_match_map AS

    SELECT

        patrick_match_id,

        match_date,


        CASE

            WHEN ",
    team_clean_sql("team1"),
    " < ",
    team_clean_sql("team2"),
    "

            THEN ",
    team_clean_sql("team1"),
    "

            ELSE ",
    team_clean_sql("team2"),
    "

        END AS team_a,


        CASE

            WHEN ",
    team_clean_sql("team1"),
    " < ",
    team_clean_sql("team2"),
    "

            THEN ",
    team_clean_sql("team2"),
    "

            ELSE ",
    team_clean_sql("team1"),
    "

        END AS team_b


    FROM patrick_match_map_raw
    "
  )
)


# ============================================================
# 18. CREATE MATCH MAPPING
# ============================================================

cat("\nCreating match mapping...\n")

dbExecute(
  con,
  "
  CREATE OR REPLACE TEMP TABLE
  match_mapping_raw AS

  SELECT DISTINCT

      u.ultimate_match_id,

      p.patrick_match_id,

      u.match_date,

      u.team_a,

      u.team_b

  FROM ultimate_match_map_clean u

  INNER JOIN patrick_match_map p

      ON u.match_date = p.match_date

      AND u.team_a = p.team_a

      AND u.team_b = p.team_b
  "
)


# ============================================================
# 19. REMOVE DUPLICATE MATCH MAPPINGS
# ============================================================

dbExecute(
  con,
  "
  CREATE OR REPLACE TEMP TABLE
  match_mapping AS

  SELECT

      ultimate_match_id,

      patrick_match_id,

      match_date,

      team_a,

      team_b

  FROM (

      SELECT

          *,

          ROW_NUMBER() OVER (

              PARTITION BY patrick_match_id

              ORDER BY ultimate_match_id

          ) AS rn

      FROM match_mapping_raw

  )

  WHERE rn = 1
  "
)


# ============================================================
# 20. CHECK MATCH MAPPING
# ============================================================

mapping_summary <- dbGetQuery(
  con,
  "
  SELECT

      (
          SELECT COUNT(DISTINCT id)
          FROM matches_ipl
      ) AS total_ipl_matches,

      (
          SELECT COUNT(DISTINCT patrick_match_id)
          FROM match_mapping
      ) AS mapped_matches
  "
)

cat("\n========================================\n")
cat("MATCH MAPPING SUMMARY\n")
cat("========================================\n")

print(
  mapping_summary,
  row.names = FALSE
)


# ============================================================
# 21. CREATE ULTIMATE BALL TABLE
# ============================================================

cat("\nCreating ultimate_balls...\n")

dbExecute(
  con,
  "
  CREATE OR REPLACE TEMP TABLE
  ultimate_balls AS

  SELECT

      u.*,

      mm.ultimate_match_id,

      mm.patrick_match_id,


      TRY_CAST(

          split_part(
              CAST(u.ball AS VARCHAR),
              '.',
              1
          )

          AS INTEGER

      ) AS over_number,


      TRY_CAST(

          split_part(
              CAST(u.ball AS VARCHAR),
              '.',
              2
          )

          AS INTEGER

      ) AS ball_number


  FROM ultimate_ipl u


  INNER JOIN match_mapping mm

      ON u.match_id = mm.ultimate_match_id
  "
)

cat("ultimate_balls created.\n")


# ============================================================
# 22. CREATE PATRICK BALL TABLE
# ============================================================

cat("\nCreating patrick_balls...\n")

dbExecute(
  con,
  "
  CREATE OR REPLACE TEMP TABLE
  patrick_balls AS

  SELECT

      d.*,

      mm.ultimate_match_id,

      mm.patrick_match_id

  FROM deliveries_ipl d

  LEFT JOIN match_mapping mm

      ON CAST(d.match_id AS VARCHAR)
      =
      CAST(mm.patrick_match_id AS VARCHAR)
  "
)

cat("patrick_balls created.\n")


# ============================================================
# 23. CREATE DYNAMIC COLUMN LISTS
# ============================================================
#
# This allows us to retain ALL columns from:
#
# matches
# deliveries
# Ultimate
#
# even when column names contain spaces.
# ============================================================

prefix_columns <- function(
    con,
    table_name,
    alias,
    prefix
) {
  
  cols <- dbGetQuery(
    con,
    paste0(
      "DESCRIBE ",
      table_name
    )
  )$column_name
  
  
  paste(
    paste0(
      
      alias,
      ".",
      
      DBI::dbQuoteIdentifier(
        con,
        cols
      ),
      
      " AS ",
      
      DBI::dbQuoteIdentifier(
        con,
        paste0(
          prefix,
          "_",
          cols
        )
      )
      
    ),
    collapse = ",\n"
  )
}


cat("\nPreparing columns...\n")


match_cols <- prefix_columns(
  con,
  "matches_ipl",
  "m",
  "match"
)


delivery_cols <- prefix_columns(
  con,
  "patrick_balls",
  "d",
  "delivery"
)


ultimate_cols <- prefix_columns(
  con,
  "ultimate_balls",
  "u",
  "ultimate"
)


# ============================================================
# 24. CREATE FINAL MASTER SHEET
# ============================================================

cat("\n========================================\n")
cat("CREATING IPL MASTER SHEET\n")
cat("========================================\n")


final_query <- paste0(
  
  "
  CREATE OR REPLACE TABLE
  ipl_master_sheet AS

  SELECT

      ",
  
  match_cols,
  
  ",

      ",
  
  delivery_cols,
  
  ",

      ",
  
  ultimate_cols,
  
  "


  FROM matches_ipl m


  INNER JOIN patrick_balls d

      ON CAST(m.id AS VARCHAR)
      =
      CAST(d.match_id AS VARCHAR)


  LEFT JOIN ultimate_balls u

      ON u.patrick_match_id = d.match_id


      AND CAST(u.innings AS VARCHAR)
      =
      CAST(d.inning AS VARCHAR)


      AND u.over_number
      =
      TRY_CAST(d.over AS INTEGER)


      AND u.ball_number
      =
      TRY_CAST(d.ball AS INTEGER)
  "
)


dbExecute(
  con,
  final_query
)


cat("\nIPL MASTER SHEET CREATED.\n")


# ============================================================
# 25. FINAL ROW COUNT
# ============================================================

final_rows <- dbGetQuery(
  con,
  "
  SELECT COUNT(*) AS n

  FROM ipl_master_sheet
  "
)$n


# ============================================================
# 26. FINAL COLUMN COUNT
# ============================================================

final_col_count <- dbGetQuery(
  con,
  "
  SELECT COUNT(*) AS n

  FROM information_schema.columns

  WHERE table_name =
        'ipl_master_sheet'
  "
)$n


# ============================================================
# 27. FINAL UNIQUE MATCH COUNT
# ============================================================

final_matches <- dbGetQuery(
  con,
  "
  SELECT

      COUNT(DISTINCT match_id) AS matches

  FROM ipl_master_sheet
  "
)$matches


# ============================================================
# 28. FINAL SEASON SUMMARY
# ============================================================

final_seasons <- dbGetQuery(
  con,
  "
  SELECT

      match_project_season AS season,

      COUNT(DISTINCT match_id)
          AS matches,

      COUNT(*) AS delivery_rows

  FROM ipl_master_sheet

  GROUP BY match_project_season

  ORDER BY season
  "
)


cat("\n========================================\n")
cat("FINAL SEASON SUMMARY\n")
cat("========================================\n")

print(
  final_seasons,
  row.names = FALSE
)


# ============================================================
# 29. FINAL 2008 CHECK
# ============================================================

final_2008 <- dbGetQuery(
  con,
  "
  SELECT

      COUNT(DISTINCT match_id)
          AS matches_2008,

      COUNT(*) AS balls_2008

  FROM ipl_master_sheet

  WHERE match_project_season = 2008
  "
)


cat("\n========================================\n")
cat("FINAL 2008 CHECK\n")
cat("========================================\n")

print(
  final_2008,
  row.names = FALSE
)


# ============================================================
# 30. DUPLICATE DELIVERY CHECK
# ============================================================

duplicate_check <- dbGetQuery(
  con,
  "
  SELECT

      delivery_match_id,

      delivery_inning,

      delivery_over,

      delivery_ball,

      COUNT(*) AS duplicate_count

  FROM ipl_master_sheet

  GROUP BY

      delivery_match_id,

      delivery_inning,

      delivery_over,

      delivery_ball

  HAVING COUNT(*) > 1

  ORDER BY duplicate_count DESC

  LIMIT 20
  "
)


cat("\n========================================\n")
cat("DUPLICATE DELIVERY CHECK\n")
cat("========================================\n")


if (nrow(duplicate_check) == 0) {
  
  cat("No duplicate delivery keys found.\n")
  
} else {
  
  cat("WARNING: Duplicate delivery keys found.\n")
  
  print(
    duplicate_check,
    row.names = FALSE
  )
}


# ============================================================
# 31. ULTIMATE FEATURE COVERAGE
# ============================================================

coverage <- dbGetQuery(
  con,
  "
  SELECT

      COUNT(*) AS total_rows,

      COUNT(ultimate_ball_length)
          AS length_present,

      COUNT(ultimate_ball_line)
          AS line_present,

      COUNT(ultimate_shot_played)
          AS shot_present,

      COUNT(ultimate_shot_direction)
          AS direction_present

  FROM ipl_master_sheet
  "
)


cat("\n========================================\n")
cat("ULTIMATE FEATURE COVERAGE\n")
cat("========================================\n")

print(
  coverage,
  row.names = FALSE
)


# ============================================================
# 32. ULTIMATE COVERAGE PERCENTAGES
# ============================================================

coverage_percent <- dbGetQuery(
  con,
  "
  SELECT

      ROUND(
          100.0 *
          COUNT(ultimate_ball_length)
          /
          COUNT(*),
          2
      ) AS length_percent,


      ROUND(
          100.0 *
          COUNT(ultimate_ball_line)
          /
          COUNT(*),
          2
      ) AS line_percent,


      ROUND(
          100.0 *
          COUNT(ultimate_shot_played)
          /
          COUNT(*),
          2
      ) AS shot_percent,


      ROUND(
          100.0 *
          COUNT(ultimate_shot_direction)
          /
          COUNT(*),
          2
      ) AS direction_percent


  FROM ipl_master_sheet
  "
)


cat("\n========================================\n")
cat("ULTIMATE COVERAGE PERCENTAGES\n")
cat("========================================\n")

print(
  coverage_percent,
  row.names = FALSE
)


# ============================================================
# 33. BALL LENGTH SUMMARY
# ============================================================

cat("\n========================================\n")
cat("BALL LENGTH\n")
cat("========================================\n")

ball_length <- dbGetQuery(
  con,
  "
  SELECT

      ultimate_ball_length,

      COUNT(*) AS balls

  FROM ipl_master_sheet

  GROUP BY ultimate_ball_length

  ORDER BY balls DESC
  "
)

print(
  ball_length,
  row.names = FALSE
)


# ============================================================
# 34. BALL LINE SUMMARY
# ============================================================

cat("\n========================================\n")
cat("BALL LINE\n")
cat("========================================\n")

ball_line <- dbGetQuery(
  con,
  "
  SELECT

      ultimate_ball_line,

      COUNT(*) AS balls

  FROM ipl_master_sheet

  GROUP BY ultimate_ball_line

  ORDER BY balls DESC
  "
)

print(
  ball_line,
  row.names = FALSE
)


# ============================================================
# 35. SHOT TYPE SUMMARY
# ============================================================

cat("\n========================================\n")
cat("SHOT TYPES\n")
cat("========================================\n")

shot_types <- dbGetQuery(
  con,
  "
  SELECT

      ultimate_shot_played,

      COUNT(*) AS balls

  FROM ipl_master_sheet

  GROUP BY ultimate_shot_played

  ORDER BY balls DESC
  "
)

print(
  shot_types,
  row.names = FALSE
)


# ============================================================
# 36. SHOT DIRECTION SUMMARY
# ============================================================

cat("\n========================================\n")
cat("SHOT DIRECTIONS\n")
cat("========================================\n")

shot_directions <- dbGetQuery(
  con,
  "
  SELECT

      ultimate_shot_direction,

      COUNT(*) AS balls

  FROM ipl_master_sheet

  GROUP BY ultimate_shot_direction

  ORDER BY balls DESC
  "
)

print(
  shot_directions,
  row.names = FALSE
)


# ============================================================
# 37. WINNER SUMMARY
# ============================================================

cat("\n========================================\n")
cat("MATCH WINNERS\n")
cat("========================================\n")

winners <- dbGetQuery(
  con,
  "
  SELECT

      match_winner AS winner,

      COUNT(DISTINCT match_id)
          AS matches

  FROM ipl_master_sheet

  WHERE match_winner IS NOT NULL

  GROUP BY match_winner

  ORDER BY matches DESC
  "
)

print(
  winners,
  row.names = FALSE
)


# ============================================================
# 38. TEAM SUMMARY
# ============================================================

cat("\n========================================\n")
cat("TEAMS IN DATASET\n")
cat("========================================\n")

teams <- dbGetQuery(
  con,
  "
  SELECT DISTINCT

      delivery_batting_team AS team

  FROM ipl_master_sheet

  WHERE delivery_batting_team IS NOT NULL

  ORDER BY team
  "
)

print(
  teams,
  row.names = FALSE
)


# ============================================================
# 39. FINAL CHECK
# ============================================================

cat("\n============================================\n")
cat("FINAL CHECK BEFORE EXPORT\n")
cat("============================================\n")

cat(
  "Rows           : ",
  final_rows,
  "\n"
)

cat(
  "Columns        : ",
  final_col_count,
  "\n"
)

cat(
  "Unique matches : ",
  final_matches,
  "\n"
)

cat(
  "Period         : IPL 2008-2024\n"
)


# ============================================================
# 40. EXPORT CSV
# ============================================================

cat("\n========================================\n")
cat("EXPORTING FINAL CSV\n")
cat("========================================\n")

cat(
  "Output file:\n",
  csv_file,
  "\n"
)


if (file.exists(csv_file)) {
  
  cat("Removing existing CSV...\n")
  
  file.remove(csv_file)
}


dbExecute(
  con,
  paste0(
    "
    COPY ipl_master_sheet

    TO '",
    csv_file,
    "'

    WITH (

        FORMAT CSV,

        HEADER TRUE

    )
    "
  )
)


# ============================================================
# 41. VERIFY CSV
# ============================================================

cat("\n========================================\n")
cat("VERIFYING CSV\n")
cat("========================================\n")


if (file.exists(csv_file)) {
  
  csv_size_gb <-
    file.info(csv_file)$size /
    (1024^3)
  
  
  cat(
    "CSV successfully created.\n"
  )
  
  cat(
    "CSV size: ",
    round(
      csv_size_gb,
      2
    ),
    " GB\n"
  )
  
  cat(
    "Location:\n",
    csv_file,
    "\n"
  )
  
} else {
  
  cat(
    "ERROR: CSV was not created.\n"
  )
}


# ============================================================
# 42. FINAL DATABASE TABLES
# ============================================================

cat("\n========================================\n")
cat("DATABASE TABLES\n")
cat("========================================\n")

print(
  dbListTables(con)
)


# ============================================================
# 43. FINAL SUCCESS MESSAGE
# ============================================================

cat("\n============================================\n")
cat("       IPL MASTER SHEET COMPLETE\n")
cat("============================================\n")

cat(
  "Dataset/Table   : ipl_master_sheet\n"
)

cat(
  "Period          : IPL 2008-2024\n"
)

cat(
  "Unique matches  : ",
  final_matches,
  "\n"
)

cat(
  "Total rows      : ",
  final_rows,
  "\n"
)

cat(
  "Total columns   : ",
  final_col_count,
  "\n"
)

cat(
  "DuckDB file:\n",
  database_file,
  "\n"
)

cat(
  "CSV file:\n",
  csv_file,
  "\n"
)

cat("============================================\n")


# ============================================================
# 44. CLOSE DATABASE
# ============================================================

dbDisconnect(
  con,
  shutdown = TRUE
)

cat("\nDuckDB connection closed.\n")
cat("ALL DONE!\n")

# Read CSV
data <- read.csv("C:/Users/mukul/OneDrive/Desktop/Downloads/IPL_Master_2008_2024.csv",
                 stringsAsFactors = FALSE)

# Replace old team names with new names
data[data == "Delhi Daredevils"] <- "Delhi Capitals"
data[data == "Kings XI Punjab"] <- "Punjab Kings"
data[data == "Deccan Chargers"] <- "Sunrisers Hyderabad"
data[data == "Royal Challengers Bangalore"] <- "Royal Challengers Bengaluru"
data[data == "Rising Pune Supergiant"] <- "Rising Pune Supergiants"

# Save updated CSV
write.csv(
  data,
  "C:/Users/mukul/OneDrive/Desktop/Downloads/IPL_Master_2008_2024_updated.csv",
  row.names = FALSE
)

cat("Team names updated successfully!\n")
unique(unlist(data[grep("team", names(data), ignore.case = TRUE)]))
teams <- unique(unlist(data[grep("team", names(data), ignore.case = TRUE)]))

teams <- sort(teams[!is.na(teams) & teams != ""])

print(teams)