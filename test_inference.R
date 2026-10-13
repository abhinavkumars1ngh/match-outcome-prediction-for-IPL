# ==============================================================================
# File: test_inference.R
# Purpose: Phase 1 Verification - Inspect saved models and test predictions
# ==============================================================================

suppressPackageStartupMessages({
  library(rpart)
  library(class)
  library(nnet)
  if (requireNamespace("randomForest", quietly = TRUE)) library(randomForest)
  if (requireNamespace("e1071", quietly = TRUE)) library(e1071)
  if (requireNamespace("gbm", quietly = TRUE)) library(gbm)
})

cat("=== Step 1: Loading Saved Models Bundle ===\n")
bundle_path <- "results/models_and_predictions.rds"
if (!file.exists(bundle_path)) {
  stop(sprintf("Bundle file '%s' does not exist!", bundle_path))
}

bundle <- readRDS(bundle_path)
cat("Successfully read RDS bundle.\n")
cat("Top-level bundle components:", paste(names(bundle), collapse = ", "), "\n\n")

cat("=== Step 2: Available Models in Bundle ===\n")
model_names <- names(bundle$models)
cat(sprintf("Total trained models in bundle: %d\n", length(model_names)))
for (i in seq_along(model_names)) {
  cat(sprintf("  [%02d] %s (Class: %s)\n", i, model_names[i], class(bundle$models[[i]])[1]))
}

cat("\n=== Step 3: Selected Feature Schema ===\n")
sel_feats <- bundle$selected_features
cat(sprintf("Total features required: %d\n", length(sel_feats)))
cat(paste(sel_feats, collapse = ", "), "\n\n")

cat("=== Step 4: Testing Model Inference on Test Sample ===\n")
sample_row <- bundle$test_data[1, sel_feats, drop = FALSE]
actual_outcome <- bundle$y_test[1]

cat("Sample Input Vector (Test match #1):\n")
print(sample_row)
cat(sprintf("Actual match outcome: team1_won = %d\n\n", actual_outcome))

# Compute scaling parameters from training data
mean_vec <- colMeans(bundle$train_data[, sel_feats])
sd_vec <- apply(bundle$train_data[, sel_feats], 2, sd)
sd_vec[sd_vec == 0] <- 1

sample_scaled <- as.data.frame(scale(sample_row, center = mean_vec, scale = sd_vec))

cat("Predictions across available models:\n")
cat(sprintf("%-25s | %-12s | %-10s\n", "Model", "P(Win Team1)", "Predicted"))
cat(paste(rep("-", 53), collapse = ""), "\n")

# 1. Logistic Regression
if ("Logistic Regression" %in% model_names) {
  p_lr <- as.numeric(predict(bundle$models[["Logistic Regression"]], newdata = sample_row, type = "response"))
  cat(sprintf("%-25s | %-12.4f | %-10d\n", "Logistic Regression", p_lr, ifelse(p_lr >= 0.5, 1, 0)))
}

# 2. Decision Tree
if ("Decision Tree" %in% model_names) {
  p_dt <- as.numeric(predict(bundle$models[["Decision Tree"]], newdata = sample_row, type = "prob")[, "1"])
  cat(sprintf("%-25s | %-12.4f | %-10d\n", "Decision Tree", p_dt, ifelse(p_dt >= 0.5, 1, 0)))
}

# 3. Random Forest
if ("Random Forest" %in% model_names && requireNamespace("randomForest", quietly = TRUE)) {
  p_rf <- as.numeric(predict(bundle$models[["Random Forest"]], newdata = sample_row, type = "prob")[, "1"])
  cat(sprintf("%-25s | %-12.4f | %-10d\n", "Random Forest", p_rf, ifelse(p_rf >= 0.5, 1, 0)))
}

# 4. KNN
if ("KNN" %in% model_names) {
  knn_obj <- bundle$models[["KNN"]]
  knn_res <- class::knn(train = knn_obj$train_x, test = sample_scaled, cl = knn_obj$train_y, k = knn_obj$k, prob = TRUE)
  prob_raw <- attr(knn_res, "prob")
  p_knn <- ifelse(knn_res == 1, prob_raw, 1 - prob_raw)
  cat(sprintf("%-25s | %-12.4f | %-10s\n", "KNN", p_knn, as.character(knn_res)))
}

# 5. Naive Bayes
if ("Naive Bayes" %in% model_names && requireNamespace("e1071", quietly = TRUE)) {
  p_nb <- as.numeric(predict(bundle$models[["Naive Bayes"]], newdata = sample_row, type = "raw")[, "1"])
  cat(sprintf("%-25s | %-12.4f | %-10d\n", "Naive Bayes", p_nb, ifelse(p_nb >= 0.5, 1, 0)))
}

# 6. SVM
if ("SVM" %in% model_names && requireNamespace("e1071", quietly = TRUE)) {
  svm_pred <- predict(bundle$models[["SVM"]], newdata = sample_scaled, probability = TRUE)
  p_svm <- as.numeric(attr(svm_pred, "probabilities")[, "1"])
  cat(sprintf("%-25s | %-12.4f | %-10d\n", "SVM (Radial)", p_svm, ifelse(p_svm >= 0.5, 1, 0)))
}

# 7. AdaBoost
if ("AdaBoost" %in% model_names && requireNamespace("gbm", quietly = TRUE)) {
  p_ada <- as.numeric(predict(bundle$models[["AdaBoost"]], newdata = sample_row, n.trees = 200, type = "response"))
  cat(sprintf("%-25s | %-12.4f | %-10d\n", "AdaBoost", p_ada, ifelse(p_ada >= 0.5, 1, 0)))
}

# 8. Gradient Boosting
if ("Gradient Boosting" %in% model_names && requireNamespace("gbm", quietly = TRUE)) {
  p_gbm <- as.numeric(predict(bundle$models[["Gradient Boosting"]], newdata = sample_row, n.trees = 250, type = "response"))
  cat(sprintf("%-25s | %-12.4f | %-10d\n", "Gradient Boosting", p_gbm, ifelse(p_gbm >= 0.5, 1, 0)))
}

# 9. MLP (Neural Net)
if ("MLP" %in% model_names) {
  p_mlp <- as.numeric(predict(bundle$models[["MLP"]], newdata = sample_scaled, type = "raw"))
  cat(sprintf("%-25s | %-12.4f | %-10d\n", "MLP (Neural Net)", p_mlp, ifelse(p_mlp >= 0.5, 1, 0)))
}

cat(paste(rep("-", 53), collapse = ""), "\n")
cat("\nPHASE 1 VERIFICATION COMPLETED SUCCESSFULLY!\n")
