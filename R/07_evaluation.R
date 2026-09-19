# ==============================================================================
# File: 07_evaluation.R
# Project: A Comparative Study of ML Models for Explainable IPL Match Outcome Prediction
# Description: Comparative evaluation metrics (Acc, Prec, Rec, F1, ROC-AUC) & Explainability
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(pROC)
  library(gbm)
})

cat("====================================================================\n")
cat("            STEP 7: MODEL EVALUATION & EXPLAINABILITY               \n")
cat("====================================================================\n\n")

bundle <- readRDS("results/models_and_predictions.rds")
models <- bundle$models
probs  <- bundle$prob
preds  <- bundle$class
y_test <- bundle$y_test
test_data <- bundle$test_data
selected_features <- bundle$selected_features

# 1. Compute Exact Performance Metrics for all 12 Models
model_names <- c(
  "Logistic Regression",
  "Decision Tree",
  "Random Forest",
  "KNN",
  "Naive Bayes",
  "SVM",
  "AdaBoost",
  "Gradient Boosting",
  "Extra Trees",
  "Bagging",
  "SGD",
  "MLP"
)

metrics_list <- list()

for (m_name in model_names) {
  y_p <- preds[[m_name]]
  y_prob <- probs[[m_name]]
  
  # Ensure probabilities are bounded in [0, 1]
  y_prob <- pmin(pmax(y_prob, 0.0001), 0.9999)
  
  tp <- sum(y_p == 1 & y_test == 1)
  tn <- sum(y_p == 0 & y_test == 0)
  fp <- sum(y_p == 1 & y_test == 0)
  fn <- sum(y_p == 0 & y_test == 1)
  total <- length(y_test)
  
  acc <- (tp + tn) / total
  prec <- ifelse((tp + fp) > 0, tp / (tp + fp), 0)
  rec  <- ifelse((tp + fn) > 0, tp / (tp + fn), 0)
  f1   <- ifelse((prec + rec) > 0, 2 * (prec * rec) / (prec + rec), 0)
  
  # ROC-AUC calculation
  roc_obj <- pROC::roc(response = y_test, predictor = y_prob, quiet = TRUE)
  auc_val <- as.numeric(pROC::auc(roc_obj))
  
  metrics_list[[m_name]] <- data.frame(
    Model = m_name,
    Accuracy = round(acc, 4),
    Precision = round(prec, 4),
    Recall = round(rec, 4),
    F1 = round(f1, 4),
    ROC_AUC = round(auc_val, 4),
    TP = tp,
    FP = fp,
    TN = tn,
    FN = fn,
    stringsAsFactors = FALSE
  )
}

eval_df <- do.call(rbind, metrics_list)
rownames(eval_df) <- NULL

# Save full comparison table to results/model_comparison.csv
write.csv(eval_df, "results/model_comparison.csv", row.names = FALSE)

cat("--------------------------------------------------------------------\n")
cat("           12 ML MODELS COMPARATIVE PERFORMANCE TABLE               \n")
cat("--------------------------------------------------------------------\n")
print(eval_df[, c("Model", "Accuracy", "Precision", "Recall", "F1", "ROC_AUC")])

# 2. Explainable AI: Feature Importance Analysis
cat("\n--------------------------------------------------------------------\n")
cat("              EXPLAINABILITY & FEATURE IMPORTANCE                   \n")
cat("--------------------------------------------------------------------\n")

# A. Random Forest Gini Importance
rf_model <- models[["Random Forest"]]
rf_imp <- randomForest::importance(rf_model)
gini_imp <- data.frame(
  Feature = rownames(rf_imp),
  RF_Gini_Importance = round(rf_imp[, "MeanDecreaseGini"], 4)
)

# B. Permutation Feature Importance (Model-Agnostic on Test Set)
cat("Calculating permutation feature importance across test set...\n")
set.seed(42)
baseline_auc <- as.numeric(pROC::auc(pROC::roc(y_test, probs[["Gradient Boosting"]], quiet = TRUE)))

perm_importance <- numeric(length(selected_features))
names(perm_importance) <- selected_features

for (k in seq_along(selected_features)) {
  feat <- selected_features[k]
  auc_drops <- numeric(10)
  
  for (iter in 1:10) {
    test_shuffled <- test_data
    test_shuffled[[feat]] <- sample(test_shuffled[[feat]])
    
    # Predict using Gradient Boosting
    p_shuff <- predict(models[["Gradient Boosting"]], newdata = test_shuffled, n.trees = 250, type = "response")
    roc_shuff <- pROC::roc(y_test, p_shuff, quiet = TRUE)
    auc_drops[iter] <- baseline_auc - as.numeric(pROC::auc(roc_shuff))
  }
  perm_importance[feat] <- mean(auc_drops)
}

perm_df <- data.frame(
  Feature = names(perm_importance),
  Permutation_Importance_DropAUC = round(perm_importance, 4)
)

importance_df <- gini_imp %>% 
  left_join(perm_df, by = "Feature") %>% 
  arrange(desc(RF_Gini_Importance))

write.csv(importance_df, "results/feature_importance.csv", row.names = FALSE)
cat("Feature Importance Rankings:\n")
print(importance_df)

cat("\nEvaluation and explainability results successfully saved to:\n")
cat("- results/model_comparison.csv\n")
cat("- results/feature_importance.csv\n")
cat("====================================================================\n\n")
