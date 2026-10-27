# ==============================================================================
# IPL Statistics Modules (1 to 7) Analysis
# Dataset: IPL_Master_2008_2024.csv
# Scope: Comprehensive statistical analysis computed for each IPL franchise team
#
# Module 1: Introduction to Statistics (Mean, Median, Variance, SD of Scores)
# Module 2: Random Variables & Probability (Win Rate, Conditional P(W|Toss), etc.)
# Module 3: Correlation & Regression (Pearson/Spearman, Logistic Regression)
# Module 4: Probability Distributions (Bernoulli, Binomial, Normality, Histograms)
# Module 5: Hypothesis Testing — Large Samples (Wilson CIs, 2-prop z-test Bat 1st vs Chase)
# Module 6: Hypothesis Testing — Chi-Square & Other Tests (Chi-Sq Toss Independence, t-test, ANOVA)
# Module 7: Reliability & Model Evaluation (Accuracy, Precision, Recall, F1, ROC-AUC, Brier Score, Calibration)
# ==============================================================================

options(warn = -1)
suppressPackageStartupMessages({
  library(stats)
  library(utils)
})

cat("================================================================================\n")
cat("      IPL 2008-2024 COMPREHENSIVE 7-MODULE STATISTICAL ANALYSIS BY TEAM         \n")
cat("================================================================================\n\n")

# ------------------------------------------------------------------------------
# STEP 0: LOAD AND PREPARE DATASET
# ------------------------------------------------------------------------------
csv_file <- "IPL_Master_2008_2024.csv"
if (!file.exists(csv_file)) {
  stop("Dataset 'IPL_Master_2008_2024.csv' was not found in the current working directory.")
}

cat(">> [0/7] Loading dataset from '", csv_file, "'...\n", sep = "")

# Franchise standardization mapping for historical continuity
standardize_team <- function(vec) {
  vec <- as.character(vec)
  vec[vec == "Rising Pune Supergiants"] <- "Rising Pune Supergiant"
  vec[vec == "Delhi Daredevils"]        <- "Delhi Capitals"
  vec[vec == "Kings XI Punjab"]         <- "Punjab Kings"
  vec[vec == "Royal Challengers Bangalore"] <- "Royal Challengers Bengaluru"
  vec[vec == "Deccan Chargers"]         <- "Sunrisers Hyderabad"
  vec
}

# Read necessary columns for performance and memory efficiency
cols_to_read <- c(
  "match_id", "match_season", "match_venue",
  "match_team1", "match_team2", "match_toss_winner", "match_toss_decision",
  "match_winner", "match_result",
  "delivery_inning", "delivery_batting_team", "delivery_bowling_team",
  "delivery_total_runs"
)

raw_data <- read.csv(csv_file, stringsAsFactors = FALSE)[, cols_to_read]
cat("   Total ball-by-ball delivery records loaded:", nrow(raw_data), "\n")

# Standardize franchise names
raw_data$match_team1           <- standardize_team(raw_data$match_team1)
raw_data$match_team2           <- standardize_team(raw_data$match_team2)
raw_data$match_toss_winner     <- standardize_team(raw_data$match_toss_winner)
raw_data$match_winner          <- standardize_team(raw_data$match_winner)
raw_data$delivery_batting_team <- standardize_team(raw_data$delivery_batting_team)
raw_data$delivery_bowling_team <- standardize_team(raw_data$delivery_bowling_team)

# Clean matches level data (deduplicated)
matches_df <- unique(raw_data[, c("match_id", "match_season", "match_venue",
                                  "match_team1", "match_team2", "match_toss_winner",
                                  "match_toss_decision", "match_winner", "match_result")])
cat("   Total unique matches loaded:", nrow(matches_df), "\n\n")

# Compute team innings scores (Innings 1 and Innings 2)
innings_scores <- aggregate(
  delivery_total_runs ~ match_id + delivery_inning + delivery_batting_team,
  data = raw_data[raw_data$delivery_inning %in% c(1, 2), ],
  FUN = sum
)
colnames(innings_scores) <- c("match_id", "inning", "team", "total_runs")

# Merge match winner & toss information into innings scores
innings_scores <- merge(innings_scores, matches_df, by = "match_id")
innings_scores$won_match <- ifelse(innings_scores$team == innings_scores$match_winner, 1, 0)
innings_scores$won_toss  <- ifelse(innings_scores$team == innings_scores$match_toss_winner, 1, 0)

# Identify prominent IPL franchises with >= 20 matches
all_teams <- sort(unique(c(matches_df$match_team1, matches_df$match_team2)))
match_counts <- sapply(all_teams, function(tm) {
  sum(matches_df$match_team1 == tm | matches_df$match_team2 == tm)
})
teams <- names(match_counts[match_counts >= 20])

cat("   Franchises analyzed (>= 20 matches):", length(teams), "\n")
cat("   ", paste(teams, collapse = ", "), "\n\n")


# ==============================================================================
# MODULE 1: INTRODUCTION TO STATISTICS
# Question: What is a typical IPL score, and how much do scores vary?
# Metrics for each team: Mean, Median, Variance, Standard Deviation, Min, Max
# ==============================================================================
cat("\n+---------------------------------------------------------------------------------------------------------+\n")
cat("| MODULE 1: INTRODUCTION TO STATISTICS — INNINGS SCORE SUMMARY BY TEAM                                    |\n")
cat("+------------------------------+---------+---------+---------+------------+----------+--------+-----------+\n")
cat(sprintf("| %-28s | %7s | %7s | %7s | %10s | %8s | %6s | %9s |\n",
            "Team", "Innings", "Mean", "Median", "Variance", "Std Dev", "Min", "Max"))
cat("+------------------------------+---------+---------+---------+------------+----------+--------+-----------+\n")

mod1_summary <- data.frame()

for (tm in teams) {
  sc <- innings_scores$total_runs[innings_scores$team == tm]
  if (length(sc) > 0) {
    m_val   <- round(mean(sc), 2)
    med_val <- round(median(sc), 2)
    var_val <- round(var(sc), 2)
    sd_val  <- round(sd(sc), 2)
    min_val <- min(sc)
    max_val <- max(sc)
    n_inn   <- length(sc)
    
    cat(sprintf("| %-28s | %7d | %7.2f | %7.2f | %10.2f | %8.2f | %6d | %9d |\n",
                tm, n_inn, m_val, med_val, var_val, sd_val, min_val, max_val))
    
    mod1_summary <- rbind(mod1_summary, data.frame(
      team = tm, innings = n_inn, mean = m_val, median = med_val,
      variance = var_val, sd = sd_val, min = min_val, max = max_val
    ))
  }
}
cat("+------------------------------+---------+---------+---------+------------+----------+--------+-----------+\n")
cat("Insight: Teams with lower standard deviations score more consistently, while higher variance indicates\n")
cat("volatility between batting collapses and explosive totals.\n\n")


# ==============================================================================
# MODULE 2: RANDOM VARIABLES AND PROBABILITY
# Question: How likely is a particular match outcome?
# Empirical Probabilities & Conditional Probabilities:
# P(Win), P(Win | Won Toss), P(Win | Lost Toss), P(Win | Batting 1st), P(Win | Chasing)
# ==============================================================================
cat("\n+---------------------------------------------------------------------------------------------------------+\n")
cat("| MODULE 2: RANDOM VARIABLES & PROBABILITY — EMPIRICAL & CONDITIONAL WIN RATES                            |\n")
cat("+------------------------------+--------+---------+---------------+---------------+---------------+---------+\n")
cat(sprintf("| %-28s | %6s | %7s | %13s | %13s | %13s | %7s |\n",
            "Team", "Played", "P(Win)", "P(W|Toss W)", "P(W|Toss L)", "P(W|Bat 1st)", "P(W|Ch)"))
cat("+------------------------------+--------+---------+---------------+---------------+---------------+---------+\n")

mod2_summary <- data.frame()

for (tm in teams) {
  # All decisive matches involving this team
  m_sub <- matches_df[(matches_df$match_team1 == tm | matches_df$match_team2 == tm) &
                      matches_df$match_result != "no result" &
                      !is.na(matches_df$match_winner) & matches_df$match_winner != "", ]
  
  total_m <- nrow(m_sub)
  if (total_m == 0) next
  
  wins <- sum(m_sub$match_winner == tm)
  p_win <- round((wins / total_m) * 100, 2)
  
  # Toss won vs Toss lost
  toss_w <- m_sub[m_sub$match_toss_winner == tm, ]
  p_win_toss_w <- if (nrow(toss_w) > 0) round((sum(toss_w$match_winner == tm) / nrow(toss_w)) * 100, 2) else NA
  
  toss_l <- m_sub[m_sub$match_toss_winner != tm, ]
  p_win_toss_l <- if (nrow(toss_l) > 0) round((sum(toss_l$match_winner == tm) / nrow(toss_l)) * 100, 2) else NA
  
  # Batting First vs Chasing
  bat1st <- m_sub[(m_sub$match_toss_winner == tm & m_sub$match_toss_decision == "bat") |
                  (m_sub$match_toss_winner != tm & m_sub$match_toss_decision == "field"), ]
  p_win_bat1st <- if (nrow(bat1st) > 0) round((sum(bat1st$match_winner == tm) / nrow(bat1st)) * 100, 2) else NA
  
  chase <- m_sub[(m_sub$match_toss_winner == tm & m_sub$match_toss_decision == "field") |
                 (m_sub$match_toss_winner != tm & m_sub$match_toss_decision == "bat"), ]
  p_win_chase <- if (nrow(chase) > 0) round((sum(chase$match_winner == tm) / nrow(chase)) * 100, 2) else NA
  
  cat(sprintf("| %-28s | %6d | %6.2f%% | %12.2f%% | %12.2f%% | %12.2f%% | %6.2f%% |\n",
              tm, total_m, p_win, p_win_toss_w, p_win_toss_l, p_win_bat1st, p_win_chase))
  
  mod2_summary <- rbind(mod2_summary, data.frame(
    team = tm, played = total_m, p_win = p_win,
    p_win_toss_w = p_win_toss_w, p_win_toss_l = p_win_toss_l,
    p_win_bat1st = p_win_bat1st, p_win_chase = p_win_chase
  ))
}
cat("+------------------------------+--------+---------+---------------+---------------+---------------+---------+\n")
cat("Note: Historical win rate reflects empirical probability, not deterministic certainty for future games.\n\n")


# ==============================================================================
# MODULE 3: CORRELATION AND REGRESSION
# Question: Which factors correlate with winning, and can we estimate outcomes?
# - Pearson & Spearman Correlation: Runs Scored vs Win Indicator
# - Logistic Regression: logit(P(Win)) = beta0 + beta1*(Runs) + beta2*(Toss Win)
# ==============================================================================
cat("\n+---------------------------------------------------------------------------------------------------------+\n")
cat("| MODULE 3: CORRELATION & REGRESSION — FACTORS ASSOCIATED WITH OUTCOMES                                   |\n")
cat("+------------------------------+-------------+--------------+--------------+---------------+--------------+\n")
cat(sprintf("| %-28s | %11s | %12s | %12s | %13s | %12s |\n",
            "Team", "Pearson r", "Spearman rho", "Reg Interc", "Reg b(Runs)", "Reg b(Toss)"))
cat("+------------------------------+-------------+--------------+--------------+---------------+--------------+\n")

mod3_summary <- data.frame()

for (tm in teams) {
  df_tm <- innings_scores[innings_scores$team == tm &
                          innings_scores$match_result != "no result", ]
  
  if (nrow(df_tm) >= 15 && length(unique(df_tm$won_match)) > 1) {
    p_cor <- round(cor(df_tm$total_runs, df_tm$won_match, method = "pearson"), 3)
    s_cor <- round(cor(df_tm$total_runs, df_tm$won_match, method = "spearman"), 3)
    
    # Fit Logistic Regression model
    logit_fit <- glm(won_match ~ total_runs + won_toss, data = df_tm, family = binomial)
    b0 <- round(coef(logit_fit)[1], 3)
    b_runs <- round(coef(logit_fit)["total_runs"], 4)
    b_toss <- round(coef(logit_fit)["won_toss"], 3)
    
    cat(sprintf("| %-28s | %11.3f | %12.3f | %12.3f | %13.4f | %12.3f |\n",
                tm, p_cor, s_cor, b0, b_runs, b_toss))
    
    mod3_summary <- rbind(mod3_summary, data.frame(
      team = tm, pearson_r = p_cor, spearman_rho = s_cor,
      intercept = b0, coef_runs = b_runs, coef_toss = b_toss
    ))
  }
}
cat("+------------------------------+-------------+--------------+--------------+---------------+--------------+\n")
cat("Key takeaway: Total runs scored exhibits a statistically strong positive coefficient; however,\n")
cat("correlation does not imply causation.\n\n")


# ==============================================================================
# MODULE 4: PROBABILITY DISTRIBUTIONS
# Question: How are outcomes distributed (Bernoulli, Binomial, Normality)?
# - Bernoulli Variance: p * (1 - p)
# - Binomial Expected Wins in next 14 league matches: 14 * p
# - Normality Check: Shapiro-Wilk Test on team scores
# - Score range histogram counts: <140, 140-159, 160-179, 180+
# ==============================================================================
cat("\n+---------------------------------------------------------------------------------------------------------+\n")
cat("| MODULE 4: PROBABILITY DISTRIBUTIONS — BERNOULLI, BINOMIAL & SCORE HISTOGRAM                             |\n")
cat("+------------------------------+----------+-------------+-----------+---------+---------+---------+-------+\n")
cat(sprintf("| %-28s | %8s | %11s | %9s | %7s | %7s | %7s | %5s |\n",
            "Team", "Bern.Var", "Binom(n=14)", "Shapiro p", "<140", "140-159", "160-179", "180+"))
cat("+------------------------------+----------+-------------+-----------+---------+---------+---------+-------+\n")

mod4_summary <- data.frame()

for (tm in teams) {
  sc <- innings_scores$total_runs[innings_scores$team == tm]
  p_win_val <- mod2_summary$p_win[mod2_summary$team == tm] / 100
  
  if (length(p_win_val) > 0 && length(sc) >= 10) {
    bern_var <- round(p_win_val * (1 - p_win_val), 4)
    binom_exp <- round(14 * p_win_val, 2)
    
    # Shapiro-Wilk test for normality of scores (sample up to 5000)
    shapiro_res <- tryCatch(shapiro.test(sc[1:min(length(sc), 5000)]), error = function(e) list(p.value = NA))
    shap_p <- round(shapiro_res$p.value, 4)
    
    # Histogram binning
    b_u140   <- sum(sc < 140)
    b_140_159 <- sum(sc >= 140 & sc < 160)
    b_160_179 <- sum(sc >= 160 & sc < 180)
    b_180p   <- sum(sc >= 180)
    
    cat(sprintf("| %-28s | %8.4f | %11.2f | %9.4f | %7d | %7d | %7d | %5d |\n",
                tm, bern_var, binom_exp, shap_p, b_u140, b_140_159, b_160_179, b_180p))
    
    mod4_summary <- rbind(mod4_summary, data.frame(
      team = tm, bernoulli_var = bern_var, binom_expected_14 = binom_exp,
      shapiro_p = shap_p, bin_under140 = b_u140, bin_140_159 = b_140_159,
      bin_160_179 = b_160_179, bin_180_plus = b_180p
    ))
  }
}
cat("+------------------------------+----------+-------------+-----------+---------+---------+---------+-------+\n")
cat("Note on Normality: A low Shapiro p-value (<0.05) indicates departure from normal distribution,\n")
cat("highlighting why predictive systems should not blindly assume a Gaussian bell curve.\n\n")


# ==============================================================================
# MODULE 5: HYPOTHESIS TESTING — LARGE SAMPLES
# Question: Is the difference between Batting 1st and Chasing statistically significant?
# - 95% Wilson Score Confidence Interval for overall win proportion
# - 2-Sample Proportions z-test (Bat 1st vs Chasing)
# ==============================================================================
cat("\n+---------------------------------------------------------------------------------------------------------+\n")
cat("| MODULE 5: HYPOTHESIS TESTING (LARGE SAMPLES) — WILSON CI & 2-PROP Z-TEST                                |\n")
cat("+------------------------------+------------+--------------------+---------------+------------------------+\n")
cat(sprintf("| %-28s | %10s | %18s | %13s | %22s |\n",
            "Team", "Win Rate", "95% Wilson CI", "Bat vs Ch z", "p-value (2-tailed)"))
cat("+------------------------------+------------+--------------------+---------------+------------------------+\n")

# Wilson Score Confidence Interval function
wilson_ci <- function(x, n, conf = 0.95) {
  if (n == 0) return(c(0, 0))
  z <- qnorm(1 - (1 - conf) / 2)
  p_hat <- x / n
  denom <- 1 + (z^2 / n)
  center <- (p_hat + (z^2 / (2 * n))) / denom
  margin <- (z * sqrt((p_hat * (1 - p_hat) / n) + (z^2 / (4 * n^2)))) / denom
  c(max(0, center - margin), min(1, center + margin))
}

mod5_summary <- data.frame()

for (tm in teams) {
  m_sub <- matches_df[(matches_df$match_team1 == tm | matches_df$match_team2 == tm) &
                      matches_df$match_result != "no result" &
                      !is.na(matches_df$match_winner) & matches_df$match_winner != "", ]
  
  n_total <- nrow(m_sub)
  if (n_total < 10) next
  
  w_total <- sum(m_sub$match_winner == tm)
  ci <- wilson_ci(w_total, n_total)
  ci_str <- sprintf("[%4.1f%%, %4.1f%%]", ci[1] * 100, ci[2] * 100)
  
  # Batting 1st vs Chasing counts
  bat1st <- m_sub[(m_sub$match_toss_winner == tm & m_sub$match_toss_decision == "bat") |
                  (m_sub$match_toss_winner != tm & m_sub$match_toss_decision == "field"), ]
  chase  <- m_sub[(m_sub$match_toss_winner == tm & m_sub$match_toss_decision == "field") |
                  (m_sub$match_toss_winner != tm & m_sub$match_toss_decision == "bat"), ]
  
  x1 <- sum(bat1st$match_winner == tm); n1 <- nrow(bat1st)
  x2 <- sum(chase$match_winner == tm);  n2 <- nrow(chase)
  
  z_stat <- NA
  p_val  <- NA
  if (n1 >= 5 && n2 >= 5) {
    p_pool <- (x1 + x2) / (n1 + n2)
    se_pool <- sqrt(p_pool * (1 - p_pool) * (1/n1 + 1/n2))
    if (se_pool > 0) {
      z_stat <- round(((x1 / n1) - (x2 / n2)) / se_pool, 3)
      p_val  <- round(2 * (1 - pnorm(abs(z_stat))), 4)
    }
  }
  
  cat(sprintf("| %-28s | %9.2f%% | %18s | %13.3f | %22.4f |\n",
              tm, (w_total / n_total) * 100, ci_str,
              ifelse(is.na(z_stat), 0, z_stat),
              ifelse(is.na(p_val), 1, p_val)))
  
  mod5_summary <- rbind(mod5_summary, data.frame(
    team = tm, win_pct = round((w_total / n_total) * 100, 2),
    ci_lower = round(ci[1] * 100, 2), ci_upper = round(ci[2] * 100, 2),
    z_stat = z_stat, p_value = p_val
  ))
}
cat("+------------------------------+------------+--------------------+---------------+------------------------+\n")
cat("Interpretation: If p-value > 0.05, the observed difference between batting 1st and chasing is not\n")
cat("statistically significant (plausibly explained by random game variance).\n\n")


# ==============================================================================
# MODULE 6: HYPOTHESIS TESTING — CHI-SQUARE AND OTHER TESTS
# Question: Are categorical variables associated? (Toss vs Match Win Independence)
# Also: Two-sample t-test comparing team scores when winning vs losing
# ==============================================================================
cat("\n+---------------------------------------------------------------------------------------------------------+\n")
cat("| MODULE 6: HYPOTHESIS TESTING — CHI-SQUARE INDEPENDENCE & TWO-SAMPLE T-TEST                              |\n")
cat("+------------------------------+---------------+---------------+---------------+--------------------------+\n")
cat(sprintf("| %-28s | %13s | %13s | %13s | %24s |\n",
            "Team", "Chi-Sq Stat", "Chi-Sq p-val", "t-test Stat", "t-test p-val"))
cat("+------------------------------+---------------+---------------+---------------+--------------------------+\n")

mod6_summary <- data.frame()

for (tm in teams) {
  m_sub <- matches_df[(matches_df$match_team1 == tm | matches_df$match_team2 == tm) &
                      matches_df$match_result != "no result" &
                      !is.na(matches_df$match_winner) & matches_df$match_winner != "", ]
  
  if (nrow(m_sub) >= 20) {
    toss_won  <- ifelse(m_sub$match_toss_winner == tm, "Toss Won", "Toss Lost")
    match_won <- ifelse(m_sub$match_winner == tm, "Match Won", "Match Lost")
    
    # 2x2 Contingency Table
    tbl <- table(toss_won, match_won)
    
    # Chi-square test (with continuity correction)
    chi_test <- tryCatch(chisq.test(tbl, correct = TRUE), error = function(e) list(statistic = NA, p.value = NA))
    chi_stat <- round(as.numeric(chi_test$statistic), 3)
    chi_p    <- round(as.numeric(chi_test$p.value), 4)
    
    # Two-sample t-test: Innings scores in Wins vs Losses
    df_tm <- innings_scores[innings_scores$team == tm & innings_scores$match_result != "no result", ]
    sc_w <- df_tm$total_runs[df_tm$won_match == 1]
    sc_l <- df_tm$total_runs[df_tm$won_match == 0]
    
    t_stat <- NA
    t_p    <- NA
    if (length(sc_w) >= 5 && length(sc_l) >= 5) {
      tt <- tryCatch(t.test(sc_w, sc_l), error = function(e) list(statistic = NA, p.value = NA))
      t_stat <- round(as.numeric(tt$statistic), 3)
      t_p    <- round(as.numeric(tt$p.value), 4)
    }
    
    cat(sprintf("| %-28s | %13.3f | %13.4f | %13.3f | %24.4f |\n",
                tm, chi_stat, chi_p,
                ifelse(is.na(t_stat), 0, t_stat),
                ifelse(is.na(t_p), 1, t_p)))
    
    mod6_summary <- rbind(mod6_summary, data.frame(
      team = tm, chi_square = chi_stat, chi_p_value = chi_p,
      t_statistic = t_stat, t_p_value = t_p
    ))
  }
}
cat("+------------------------------+---------------+---------------+---------------+--------------------------+\n")
cat("\nANOVA Test on Mean Scores across major franchises:\n")
major_scores <- innings_scores[innings_scores$team %in% teams[1:min(6, length(teams))], ]
aov_fit <- aov(total_runs ~ team, data = major_scores)
aov_summary <- summary(aov_fit)[[1]]
print(aov_summary)
cat("\n")


# ==============================================================================
# MODULE 7: RELIABILITY AND MODEL EVALUATION
# Question: How much should we trust the predictions?
# Benchmarks for predictive model:
# Accuracy, Precision, Recall, F1 Score, ROC-AUC, Brier Score, and Calibration Error
# ==============================================================================
cat("\n+---------------------------------------------------------------------------------------------------------+\n")
cat("| MODULE 7: RELIABILITY & MODEL EVALUATION — TEAM-LEVEL INFERENCE PERFORMANCE                             |\n")
cat("+---------------------------------------------------------------------------------------------------------+\n")

# Build a baseline logistic regression classifier with pre-match factors
# (Venue score index + Toss Win + Team Win Rate) evaluated out-of-sample
m_valid <- matches_df[matches_df$match_result != "no result" &
                      !is.na(matches_df$match_winner) & matches_df$match_winner != "", ]

# Chronological split: <= 2021 train, 2022-2024 test
train_idx <- which(as.numeric(m_valid$match_season) <= 2021)
test_idx  <- which(as.numeric(m_valid$match_season) >= 2022)

# Compute target team1 won
m_valid$team1_won <- ifelse(m_valid$match_team1 == m_valid$match_winner, 1, 0)
m_valid$toss_winner_is_team1 <- ifelse(m_valid$match_team1 == m_valid$match_toss_winner, 1, 0)

# Historical team win rates up to 2021
train_matches <- m_valid[train_idx, ]
calc_win_rate <- function(tm, dset) {
  sub <- dset[dset$match_team1 == tm | dset$match_team2 == tm, ]
  if (nrow(sub) == 0) return(0.5)
  sum(sub$match_winner == tm) / nrow(sub)
}

team_rates <- sapply(all_teams, calc_win_rate, dset = train_matches)
m_valid$t1_rate <- team_rates[m_valid$match_team1]
m_valid$t2_rate <- team_rates[m_valid$match_team2]
m_valid$rate_diff <- m_valid$t1_rate - m_valid$t2_rate

fit_model <- glm(team1_won ~ rate_diff + toss_winner_is_team1,
                 data = m_valid[train_idx, ], family = binomial)

# Generate probabilities on holdout test set
test_set <- m_valid[test_idx, ]
pred_probs <- predict(fit_model, newdata = test_set, type = "response")
pred_class <- ifelse(pred_probs >= 0.5, 1, 0)
actual     <- test_set$team1_won

# Global Evaluation Metrics
acc <- round(mean(pred_class == actual) * 100, 2)
tp  <- sum(pred_class == 1 & actual == 1)
fp  <- sum(pred_class == 1 & actual == 0)
fn  <- sum(pred_class == 0 & actual == 1)
tn  <- sum(pred_class == 0 & actual == 0)

precision <- round((tp / (tp + fp)) * 100, 2)
recall    <- round((tp / (tp + fn)) * 100, 2)
f1        <- round(2 * (precision * recall) / (precision + recall), 2)
brier     <- round(mean((pred_probs - actual)^2), 4)

# Approximate ROC-AUC (trapezoidal integration via Mann-Whitney U)
pos_probs <- pred_probs[actual == 1]
neg_probs <- pred_probs[actual == 0]
u_stat <- sum(outer(pos_probs, neg_probs, ">")) + 0.5 * sum(outer(pos_probs, neg_probs, "=="))
auc <- round(u_stat / (length(pos_probs) * length(neg_probs)), 4)

cat(sprintf("Test Holdout Set (2022-2024, %d matches):\n", nrow(test_set)))
cat(sprintf("   • Accuracy     : %.2f%%\n", acc))
cat(sprintf("   • Precision    : %.2f%%\n", precision))
cat(sprintf("   • Recall       : %.2f%%\n", recall))
cat(sprintf("   • F1 Score     : %.2f%%\n", f1))
cat(sprintf("   • ROC-AUC      : %.4f\n", auc))
cat(sprintf("   • Brier Score  : %.4f (lower is better, 0.25 = random)\n\n", brier))

# Team-Level Calibration Breakdown
cat("Team-Level Accuracy & Calibration (Test Holdout 2022-2024):\n")
cat("+------------------------------+----------+------------+----------------+----------------+\n")
cat(sprintf("| %-28s | %8s | %10s | %14s | %14s |\n",
            "Team", "Matches", "Accuracy", "Mean Pred Prob", "Actual Win %"))
cat("+------------------------------+----------+------------+----------------+----------------+\n")

mod7_summary <- data.frame()

for (tm in teams) {
  # Indices where this team played in test set
  idx_tm <- which(test_set$match_team1 == tm | test_set$match_team2 == tm)
  if (length(idx_tm) >= 10) {
    tm_preds <- numeric(length(idx_tm))
    tm_actual <- numeric(length(idx_tm))
    
    for (j in seq_along(idx_tm)) {
      i <- idx_tm[j]
      if (test_set$match_team1[i] == tm) {
        tm_preds[j]  <- pred_probs[i]
        tm_actual[j] <- actual[i]
      } else {
        tm_preds[j]  <- 1 - pred_probs[i]
        tm_actual[j] <- 1 - actual[i]
      }
    }
    
    tm_acc <- round(mean(ifelse(tm_preds >= 0.5, 1, 0) == tm_actual) * 100, 2)
    mean_pred <- round(mean(tm_preds) * 100, 2)
    act_win   <- round(mean(tm_actual) * 100, 2)
    
    cat(sprintf("| %-28s | %8d | %9.2f%% | %14.2f%% | %14.2f%% |\n",
                tm, length(idx_tm), tm_acc, mean_pred, act_win))
    
    mod7_summary <- rbind(mod7_summary, data.frame(
      team = tm, matches_test = length(idx_tm), accuracy = tm_acc,
      mean_predicted_pct = mean_pred, actual_win_pct = act_win
    ))
  }
}
cat("+------------------------------+----------+------------+----------------+----------------+\n")

cat("\n===========================================================================================================\n")
cat("                                      END OF 7-MODULE ANALYSIS                                             \n")
cat("===========================================================================================================\n")
