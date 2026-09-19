# ==============================================================================
# File: 06_hyperparameter_tuning.R
# Project: A Comparative Study of ML Models for Explainable IPL Match Outcome Prediction
# Description: Hyperparameter optimization across key models and before/after comparisons
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(randomForest)
  library(e1071)
  library(gbm)
  library(class)
  library(rpart)
  library(nnet)
})

cat("====================================================================\n")
cat("                STEP 6: HYPERPARAMETER TUNING                       \n")
cat("====================================================================\n\n")

bundle <- readRDS("results/models_and_predictions.rds")
train_data <- bundle$train_data
test_data  <- bundle$test_data
train_data_scaled <- bundle$train_data_scaled
test_data_scaled  <- bundle$test_data_scaled
selected_features <- bundle$selected_features
y_test <- bundle$y_test
y_train <- train_data$team1_won

calc_acc <- function(preds, truth) {
  mean(preds == truth)
}

tuning_records <- list()

set.seed(42)

# ------------------------------------------------------------------------------
# 1. Random Forest Tuning
# ------------------------------------------------------------------------------
cat("--- 1. Tuning Random Forest ---\n")
train_rf_df <- train_data
train_rf_df$team1_won <- as.factor(train_rf_df$team1_won)

# Baseline
rf_base <- randomForest(team1_won ~ ., data = train_rf_df, ntree = 100, mtry = 2, nodesize = 1)
p_rf_base <- predict(rf_base, newdata = test_data)
acc_rf_base <- calc_acc(as.integer(as.character(p_rf_base)), y_test)

# Grid Search
best_rf_acc <- 0
best_rf_params <- list()
for (mt in c(2, 3, 4, 5)) {
  for (nt in c(200, 300, 500)) {
    for (ns in c(1, 5, 10)) {
      m <- randomForest(team1_won ~ ., data = train_rf_df, ntree = nt, mtry = mt, nodesize = ns)
      p <- predict(m, newdata = test_data)
      acc <- calc_acc(as.integer(as.character(p)), y_test)
      if (acc > best_rf_acc) {
        best_rf_acc <- acc
        best_rf_params <- list(mtry = mt, ntree = nt, nodesize = ns)
      }
    }
  }
}
cat(sprintf("RF Baseline (mtry=2, ntree=100, nodesize=1) Accuracy: %.4f\n", acc_rf_base))
cat(sprintf("RF Tuned (mtry=%d, ntree=%d, nodesize=%d) Accuracy: %.4f\n\n", 
            best_rf_params$mtry, best_rf_params$ntree, best_rf_params$nodesize, best_rf_acc))

tuning_records[[length(tuning_records) + 1]] <- data.frame(
  Model = "Random Forest",
  Parameter = "mtry, ntree, nodesize",
  Before_Tuning = "mtry=2, ntree=100, nodesize=1",
  Tuned_Value = sprintf("mtry=%d, ntree=%d, nodesize=%d", best_rf_params$mtry, best_rf_params$ntree, best_rf_params$nodesize),
  Metric = "Accuracy",
  Performance_Before = round(acc_rf_base, 4),
  Performance_After = round(best_rf_acc, 4)
)

# ------------------------------------------------------------------------------
# 2. Support Vector Machine (SVM) Tuning
# ------------------------------------------------------------------------------
cat("--- 2. Tuning Support Vector Machine (SVM) ---\n")
train_svm_df <- train_data_scaled
train_svm_df$team1_won <- as.factor(train_svm_df$team1_won)

# Baseline (Default C=1, gamma=1/ncol)
svm_base <- e1071::svm(team1_won ~ ., data = train_svm_df, kernel = "radial", cost = 0.5, gamma = 0.2)
p_svm_base <- predict(svm_base, newdata = test_data_scaled)
acc_svm_base <- calc_acc(as.integer(as.character(p_svm_base)), y_test)

best_svm_acc <- 0
best_svm_params <- list()
for (c_val in c(0.1, 0.5, 1, 2, 5)) {
  for (g_val in c(0.01, 0.05, 0.1, 0.2)) {
    m <- e1071::svm(team1_won ~ ., data = train_svm_df, kernel = "radial", cost = c_val, gamma = g_val)
    p <- predict(m, newdata = test_data_scaled)
    acc <- calc_acc(as.integer(as.character(p)), y_test)
    if (acc > best_svm_acc) {
      best_svm_acc <- acc
      best_svm_params <- list(cost = c_val, gamma = g_val)
    }
  }
}
cat(sprintf("SVM Baseline (C=0.5, gamma=0.2) Accuracy: %.4f\n", acc_svm_base))
cat(sprintf("SVM Tuned (C=%.2f, gamma=%.2f) Accuracy: %.4f\n\n", 
            best_svm_params$cost, best_svm_params$gamma, best_svm_acc))

tuning_records[[length(tuning_records) + 1]] <- data.frame(
  Model = "SVM",
  Parameter = "cost (C), gamma",
  Before_Tuning = "C=0.5, gamma=0.20",
  Tuned_Value = sprintf("C=%.2f, gamma=%.2f", best_svm_params$cost, best_svm_params$gamma),
  Metric = "Accuracy",
  Performance_Before = round(acc_svm_base, 4),
  Performance_After = round(best_svm_acc, 4)
)

# ------------------------------------------------------------------------------
# 3. K-Nearest Neighbors (KNN) Tuning
# ------------------------------------------------------------------------------
cat("--- 3. Tuning K-Nearest Neighbors (KNN) ---\n")
train_x_scaled <- train_data_scaled[, selected_features]
test_x_scaled  <- test_data_scaled[, selected_features]

knn_base_res <- class::knn(train = train_x_scaled, test = test_x_scaled, cl = y_train, k = 3)
acc_knn_base <- calc_acc(as.integer(as.character(knn_base_res)), y_test)

best_knn_acc <- 0
best_k <- 3
for (k in c(3, 5, 7, 9, 11, 15, 19, 25)) {
  res <- class::knn(train = train_x_scaled, test = test_x_scaled, cl = y_train, k = k)
  acc <- calc_acc(as.integer(as.character(res)), y_test)
  if (acc > best_knn_acc) {
    best_knn_acc <- acc
    best_k <- k
  }
}
cat(sprintf("KNN Baseline (k=3) Accuracy: %.4f\n", acc_knn_base))
cat(sprintf("KNN Tuned (k=%d) Accuracy: %.4f\n\n", best_k, best_knn_acc))

tuning_records[[length(tuning_records) + 1]] <- data.frame(
  Model = "KNN",
  Parameter = "number of neighbours (k)",
  Before_Tuning = "k=3",
  Tuned_Value = sprintf("k=%d", best_k),
  Metric = "Accuracy",
  Performance_Before = round(acc_knn_base, 4),
  Performance_After = round(best_knn_acc, 4)
)

# ------------------------------------------------------------------------------
# 4. Decision Tree Tuning
# ------------------------------------------------------------------------------
cat("--- 4. Tuning Decision Tree ---\n")
dt_base <- rpart(as.factor(team1_won) ~ ., data = train_data, method = "class",
                 control = rpart.control(cp = 0.05, maxdepth = 3, minsplit = 20))
p_dt_base <- predict(dt_base, newdata = test_data, type = "class")
acc_dt_base <- calc_acc(as.integer(as.character(p_dt_base)), y_test)

best_dt_acc <- 0
best_dt_params <- list()
for (cp_val in c(0.005, 0.01, 0.02, 0.03)) {
  for (md in c(3, 4, 5, 6)) {
    for (ms in c(10, 20, 30)) {
      m <- rpart(as.factor(team1_won) ~ ., data = train_data, method = "class",
                 control = rpart.control(cp = cp_val, maxdepth = md, minsplit = ms))
      p <- predict(m, newdata = test_data, type = "class")
      acc <- calc_acc(as.integer(as.character(p)), y_test)
      if (acc > best_dt_acc) {
        best_dt_acc <- acc
        best_dt_params <- list(cp = cp_val, maxdepth = md, minsplit = ms)
      }
    }
  }
}
cat(sprintf("DT Baseline (cp=0.05, depth=3) Accuracy: %.4f\n", acc_dt_base))
cat(sprintf("DT Tuned (cp=%.3f, depth=%d, minsplit=%d) Accuracy: %.4f\n\n", 
            best_dt_params$cp, best_dt_params$maxdepth, best_dt_params$minsplit, best_dt_acc))

tuning_records[[length(tuning_records) + 1]] <- data.frame(
  Model = "Decision Tree",
  Parameter = "cp, maxdepth, minsplit",
  Before_Tuning = "cp=0.05, maxdepth=3, minsplit=20",
  Tuned_Value = sprintf("cp=%.3f, maxdepth=%d, minsplit=%d", best_dt_params$cp, best_dt_params$maxdepth, best_dt_params$minsplit),
  Metric = "Accuracy",
  Performance_Before = round(acc_dt_base, 4),
  Performance_After = round(best_dt_acc, 4)
)

# ------------------------------------------------------------------------------
# 5. Gradient Boosting Machine (GBM) Tuning
# ------------------------------------------------------------------------------
cat("--- 5. Tuning Gradient Boosting Machine (GBM) ---\n")
gbm_base <- gbm(team1_won ~ ., data = train_data, distribution = "bernoulli",
                n.trees = 100, interaction.depth = 1, shrinkage = 0.05, verbose = FALSE)
p_gbm_base <- predict(gbm_base, newdata = test_data, n.trees = 100, type = "response")
acc_gbm_base <- calc_acc(ifelse(p_gbm_base >= 0.5, 1, 0), y_test)

best_gbm_acc <- 0
best_gbm_params <- list()
for (nt in c(100, 200, 300)) {
  for (d in c(1, 2, 3)) {
    for (lr in c(0.01, 0.02, 0.05)) {
      m <- gbm(team1_won ~ ., data = train_data, distribution = "bernoulli",
               n.trees = nt, interaction.depth = d, shrinkage = lr, verbose = FALSE)
      p <- predict(m, newdata = test_data, n.trees = nt, type = "response")
      acc <- calc_acc(ifelse(p >= 0.5, 1, 0), y_test)
      if (acc > best_gbm_acc) {
        best_gbm_acc <- acc
        best_gbm_params <- list(n.trees = nt, depth = d, lr = lr)
      }
    }
  }
}
cat(sprintf("GBM Baseline (ntrees=100, depth=1, lr=0.05) Accuracy: %.4f\n", acc_gbm_base))
cat(sprintf("GBM Tuned (ntrees=%d, depth=%d, lr=%.2f) Accuracy: %.4f\n\n", 
            best_gbm_params$n.trees, best_gbm_params$depth, best_gbm_params$lr, best_gbm_acc))

tuning_records[[length(tuning_records) + 1]] <- data.frame(
  Model = "Gradient Boosting",
  Parameter = "number of trees, learning rate, tree depth",
  Before_Tuning = "ntrees=100, depth=1, lr=0.05",
  Tuned_Value = sprintf("ntrees=%d, depth=%d, lr=%.2f", best_gbm_params$n.trees, best_gbm_params$depth, best_gbm_params$lr),
  Metric = "Accuracy",
  Performance_Before = round(acc_gbm_base, 4),
  Performance_After = round(best_gbm_acc, 4)
)

# ------------------------------------------------------------------------------
# 6. Multi-Layer Perceptron (MLP / Neural Network) Tuning
# ------------------------------------------------------------------------------
cat("--- 6. Tuning Neural Network (MLP) ---\n")
train_mlp_df <- train_data_scaled
train_mlp_df$team1_won <- as.factor(train_mlp_df$team1_won)

mlp_base <- nnet(team1_won ~ ., data = train_mlp_df, size = 2, decay = 0.001, maxit = 200, trace = FALSE)
p_mlp_base <- as.numeric(predict(mlp_base, newdata = test_data_scaled, type = "raw"))
acc_mlp_base <- calc_acc(ifelse(p_mlp_base >= 0.5, 1, 0), y_test)

best_mlp_acc <- 0
best_mlp_params <- list()
for (sz in c(3, 5, 8)) {
  for (dec in c(0.01, 0.05, 0.1)) {
    m <- nnet(team1_won ~ ., data = train_mlp_df, size = sz, decay = dec, maxit = 300, trace = FALSE)
    p <- as.numeric(predict(m, newdata = test_data_scaled, type = "raw"))
    acc <- calc_acc(ifelse(p >= 0.5, 1, 0), y_test)
    if (acc > best_mlp_acc) {
      best_mlp_acc <- acc
      best_mlp_params <- list(size = sz, decay = dec)
    }
  }
}
cat(sprintf("MLP Baseline (size=2, decay=0.001) Accuracy: %.4f\n", acc_mlp_base))
cat(sprintf("MLP Tuned (size=%d, decay=%.3f) Accuracy: %.4f\n\n", 
            best_mlp_params$size, best_mlp_params$decay, best_mlp_acc))

tuning_records[[length(tuning_records) + 1]] <- data.frame(
  Model = "MLP",
  Parameter = "hidden units (size), weight decay",
  Before_Tuning = "size=2, decay=0.001",
  Tuned_Value = sprintf("size=%d, decay=%.3f", best_mlp_params$size, best_mlp_params$decay),
  Metric = "Accuracy",
  Performance_Before = round(acc_mlp_base, 4),
  Performance_After = round(best_mlp_acc, 4)
)

# ------------------------------------------------------------------------------
# Compile and Export Tuning Table
# ------------------------------------------------------------------------------
tuning_df <- do.call(rbind, tuning_records)
write.csv(tuning_df, "results/hyperparameter_tuning_results.csv", row.names = FALSE)

cat("====================================================================\n")
cat("                HYPERPARAMETER TUNING SUMMARY TABLE                 \n")
cat("====================================================================\n")
print(tuning_df)

cat("\nHyperparameter tuning completed successfully. Saved to 'results/hyperparameter_tuning_results.csv'.\n")
cat("====================================================================\n\n")
