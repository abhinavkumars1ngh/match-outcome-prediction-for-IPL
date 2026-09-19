# ==============================================================================
# File: 05_models.R
# Project: A Comparative Study of ML Models for Explainable IPL Match Outcome Prediction
# Description: Implementation and training of 12 distinct ML/DL classification algorithms
# ==============================================================================

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(rpart)
  library(randomForest)
  library(class)
  library(e1071)
  library(gbm)
  library(ranger)
  library(ipred)
  library(glmnet)
  library(nnet)
})

cat("====================================================================\n")
cat("            STEP 5: IMPLEMENTATION OF 12 ML CLASSIFIERS             \n")
cat("====================================================================\n\n")

# 1. Load Data and Selected Features
db_path <- "database/ipl_database.sqlite"
con <- dbConnect(SQLite(), db_path)
features_df <- dbGetQuery(con, "SELECT * FROM model_features ORDER BY date ASC, id ASC;")
dbDisconnect(con)

selected_features <- readRDS("results/selected_features.rds")
cat("Loaded selected features (", length(selected_features), "):\n")
cat(paste(selected_features, collapse = ", "), "\n\n")

# 2. Time-Aware Chronological Train/Test Split
# Train: Seasons 2008-2021 (earlier historical matches)
# Test: Seasons 2022-2024 (recent IPL seasons, avoids lookahead bias)

train_idx <- which(!(features_df$season %in% c("2022", "2023", "2024")))
test_idx <- which(features_df$season %in% c("2022", "2023", "2024"))

cat(sprintf("Time-aware chronological split:\n"))
cat(sprintf("Training set : %d matches (Seasons 2008-2021)\n", length(train_idx)))
cat(sprintf("Testing set  : %d matches (Seasons 2022-2024)\n\n", length(test_idx)))

train_data <- features_df[train_idx, c(selected_features, "team1_won")]
test_data  <- features_df[test_idx, c(selected_features, "team1_won")]

y_train <- train_data$team1_won
y_test  <- test_data$team1_won

cat(sprintf("Training class distribution : Class 0 = %d, Class 1 = %d (%.1f%%)\n",
            sum(y_train == 0), sum(y_train == 1), mean(y_train) * 100))
cat(sprintf("Testing class distribution  : Class 0 = %d, Class 1 = %d (%.1f%%)\n\n",
            sum(y_test == 0), sum(y_test == 1), mean(y_test) * 100))

# 3. Standardize Features for Distance/Gradient Models
train_x <- train_data[, selected_features]
test_x  <- test_data[, selected_features]

mean_vec <- colMeans(train_x)
sd_vec   <- apply(train_x, 2, sd)
sd_vec[sd_vec == 0] <- 1

train_x_scaled <- as.data.frame(scale(train_x, center = mean_vec, scale = sd_vec))
test_x_scaled  <- as.data.frame(scale(test_x, center = mean_vec, scale = sd_vec))

train_data_scaled <- cbind(train_x_scaled, team1_won = y_train)
test_data_scaled  <- cbind(test_x_scaled, team1_won = y_test)

# Storage for model objects and predictions
models_list <- list()
predictions_prob <- list()
predictions_class <- list()

set.seed(42)

# ------------------------------------------------------------------------------
# Model 1: Logistic Regression
# ------------------------------------------------------------------------------
cat("Training [1/12] Logistic Regression...\n")
m_lr <- glm(team1_won ~ ., data = train_data, family = binomial(link = "logit"))
p_lr <- predict(m_lr, newdata = test_data, type = "response")
models_list[["Logistic Regression"]] <- m_lr
predictions_prob[["Logistic Regression"]] <- as.numeric(p_lr)
predictions_class[["Logistic Regression"]] <- ifelse(p_lr >= 0.5, 1, 0)

# ------------------------------------------------------------------------------
# Model 2: Decision Tree (CART)
# ------------------------------------------------------------------------------
cat("Training [2/12] Decision Tree (CART)...\n")
m_dt <- rpart(as.factor(team1_won) ~ ., data = train_data, method = "class", 
              control = rpart.control(cp = 0.015, minsplit = 20, maxdepth = 5))
p_dt <- predict(m_dt, newdata = test_data, type = "prob")[, "1"]
models_list[["Decision Tree"]] <- m_dt
predictions_prob[["Decision Tree"]] <- as.numeric(p_dt)
predictions_class[["Decision Tree"]] <- ifelse(p_dt >= 0.5, 1, 0)

# ------------------------------------------------------------------------------
# Model 3: Random Forest
# ------------------------------------------------------------------------------
cat("Training [3/12] Random Forest...\n")
train_rf_df <- train_data
train_rf_df$team1_won <- as.factor(train_rf_df$team1_won)
m_rf <- randomForest(team1_won ~ ., data = train_rf_df, ntree = 300, mtry = 3, importance = TRUE)
p_rf <- predict(m_rf, newdata = test_data, type = "prob")[, "1"]
models_list[["Random Forest"]] <- m_rf
predictions_prob[["Random Forest"]] <- as.numeric(p_rf)
predictions_class[["Random Forest"]] <- ifelse(p_rf >= 0.5, 1, 0)

# ------------------------------------------------------------------------------
# Model 4: K-Nearest Neighbors (KNN)
# ------------------------------------------------------------------------------
cat("Training [4/12] K-Nearest Neighbors (KNN)...\n")
k_val <- 11
knn_res <- class::knn(train = train_x_scaled, test = test_x_scaled, cl = y_train, k = k_val, prob = TRUE)
knn_prob_raw <- attr(knn_res, "prob")
p_knn <- ifelse(knn_res == 1, knn_prob_raw, 1 - knn_prob_raw)
models_list[["KNN"]] <- list(k = k_val, train_x = train_x_scaled, train_y = y_train)
predictions_prob[["KNN"]] <- as.numeric(p_knn)
predictions_class[["KNN"]] <- as.integer(as.character(knn_res))

# ------------------------------------------------------------------------------
# Model 5: Naive Bayes
# ------------------------------------------------------------------------------
cat("Training [5/12] Naive Bayes...\n")
m_nb <- e1071::naiveBayes(as.factor(team1_won) ~ ., data = train_data)
p_nb <- predict(m_nb, newdata = test_data, type = "raw")[, "1"]
models_list[["Naive Bayes"]] <- m_nb
predictions_prob[["Naive Bayes"]] <- as.numeric(p_nb)
predictions_class[["Naive Bayes"]] <- ifelse(p_nb >= 0.5, 1, 0)

# ------------------------------------------------------------------------------
# Model 6: Support Vector Machine (SVM Radial)
# ------------------------------------------------------------------------------
cat("Training [6/12] Support Vector Machine (SVM)...\n")
train_svm_df <- train_data_scaled
train_svm_df$team1_won <- as.factor(train_svm_df$team1_won)
m_svm <- e1071::svm(team1_won ~ ., data = train_svm_df, kernel = "radial", cost = 1.0, gamma = 0.05, probability = TRUE)
svm_pred <- predict(m_svm, newdata = test_data_scaled, probability = TRUE)
p_svm <- attr(svm_pred, "probabilities")[, "1"]
models_list[["SVM"]] <- m_svm
predictions_prob[["SVM"]] <- as.numeric(p_svm)
predictions_class[["SVM"]] <- ifelse(p_svm >= 0.5, 1, 0)

# ------------------------------------------------------------------------------
# Model 7: AdaBoost
# ------------------------------------------------------------------------------
cat("Training [7/12] AdaBoost...\n")
m_ada <- gbm(team1_won ~ ., data = train_data, distribution = "adaboost",
             n.trees = 200, interaction.depth = 2, shrinkage = 0.03, cv.folds = 3, verbose = FALSE)
p_ada <- predict(m_ada, newdata = test_data, n.trees = 200, type = "response")
models_list[["AdaBoost"]] <- m_ada
predictions_prob[["AdaBoost"]] <- as.numeric(p_ada)
predictions_class[["AdaBoost"]] <- ifelse(p_ada >= 0.5, 1, 0)

# ------------------------------------------------------------------------------
# Model 8: Gradient Boosting (GBM Bernoulli)
# ------------------------------------------------------------------------------
cat("Training [8/12] Gradient Boosting (GBM)...\n")
m_gbm <- gbm(team1_won ~ ., data = train_data, distribution = "bernoulli",
             n.trees = 250, interaction.depth = 3, shrinkage = 0.02, cv.folds = 3, verbose = FALSE)
p_gbm <- predict(m_gbm, newdata = test_data, n.trees = 250, type = "response")
models_list[["Gradient Boosting"]] <- m_gbm
predictions_prob[["Gradient Boosting"]] <- as.numeric(p_gbm)
predictions_class[["Gradient Boosting"]] <- ifelse(p_gbm >= 0.5, 1, 0)

# ------------------------------------------------------------------------------
# Model 9: Extra Trees (Extremely Randomized Trees)
# ------------------------------------------------------------------------------
cat("Training [9/12] Extra Trees (ranger)...\n")
train_et_df <- train_data
train_et_df$team1_won <- as.factor(train_et_df$team1_won)
m_et <- ranger(team1_won ~ ., data = train_et_df, splitrule = "extratrees", 
               num.trees = 300, mtry = 3, probability = TRUE)
p_et <- predict(m_et, data = test_data)$predictions[, "1"]
models_list[["Extra Trees"]] <- m_et
predictions_prob[["Extra Trees"]] <- as.numeric(p_et)
predictions_class[["Extra Trees"]] <- ifelse(p_et >= 0.5, 1, 0)

# ------------------------------------------------------------------------------
# Model 10: Bagging (Bootstrap Aggregating)
# ------------------------------------------------------------------------------
cat("Training [10/12] Bagging (ipred)...\n")
train_bag_df <- train_data
train_bag_df$team1_won <- as.factor(train_bag_df$team1_won)
m_bag <- ipred::bagging(team1_won ~ ., data = train_bag_df, nbagg = 50)
p_bag <- predict(m_bag, newdata = test_data, type = "prob")[, "1"]
models_list[["Bagging"]] <- m_bag
predictions_prob[["Bagging"]] <- as.numeric(p_bag)
predictions_class[["Bagging"]] <- ifelse(p_bag >= 0.5, 1, 0)

# ------------------------------------------------------------------------------
# Model 11: Regularized Logistic / SGD (ElasticNet)
# ------------------------------------------------------------------------------
cat("Training [11/12] Regularized Logistic / SGD (ElasticNet)...\n")
x_mat_train <- as.matrix(train_x_scaled)
x_mat_test  <- as.matrix(test_x_scaled)
m_sgd <- glmnet::cv.glmnet(x_mat_train, y_train, family = "binomial", alpha = 0.5, nfolds = 5)
p_sgd <- as.numeric(predict(m_sgd, newx = x_mat_test, s = "lambda.min", type = "response"))
models_list[["SGD"]] <- m_sgd
predictions_prob[["SGD"]] <- p_sgd
predictions_class[["SGD"]] <- ifelse(p_sgd >= 0.5, 1, 0)

# ------------------------------------------------------------------------------
# Model 12: Multi-Layer Perceptron / Neural Network (MLP)
# ------------------------------------------------------------------------------
cat("Training [12/12] Neural Network (MLP)...\n")
train_mlp_df <- train_data_scaled
train_mlp_df$team1_won <- as.factor(train_mlp_df$team1_won)
m_mlp <- nnet(team1_won ~ ., data = train_mlp_df, size = 5, decay = 0.05, maxit = 500, trace = FALSE)
p_mlp <- as.numeric(predict(m_mlp, newdata = test_data_scaled, type = "raw"))
models_list[["MLP"]] <- m_mlp
predictions_prob[["MLP"]] <- p_mlp
predictions_class[["MLP"]] <- ifelse(p_mlp >= 0.5, 1, 0)

cat("\nAll 12 classification models successfully trained.\n")

# Save objects for evaluation and visualization
bundle <- list(
  models = models_list,
  prob = predictions_prob,
  class = predictions_class,
  y_test = y_test,
  test_data = test_data,
  test_data_scaled = test_data_scaled,
  train_data = train_data,
  train_data_scaled = train_data_scaled,
  selected_features = selected_features
)

saveRDS(bundle, "results/models_and_predictions.rds")
cat("Saved models and test predictions bundle to 'results/models_and_predictions.rds'.\n")
cat("====================================================================\n\n")
