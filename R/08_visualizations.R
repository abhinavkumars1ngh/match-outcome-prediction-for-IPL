# ==============================================================================
# File: 08_visualizations.R
# Project: A Comparative Study of ML Models for Explainable IPL Match Outcome Prediction
# Description: Publication-quality comparative visualizations of model performance
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(pROC)
  library(corrplot)
  library(scales)
})

cat("====================================================================\n")
cat("            STEP 8: GENERATING COMPARATIVE VISUALIZATIONS           \n")
cat("====================================================================\n\n")

# Ensure output directories exist
dir.create("results/plots", showWarnings = FALSE, recursive = TRUE)
dir.create("results/roc_curves", showWarnings = FALSE, recursive = TRUE)
dir.create("results/confusion_matrices", showWarnings = FALSE, recursive = TRUE)

# Load data and results
bundle <- readRDS("results/models_and_predictions.rds")
eval_df <- read.csv("results/model_comparison.csv", stringsAsFactors = FALSE)
importance_df <- read.csv("results/feature_importance.csv", stringsAsFactors = FALSE)
features_df <- read.csv("data/ipl_features.csv", stringsAsFactors = FALSE)
selected_features <- readRDS("results/selected_features.rds")

y_test <- bundle$y_test
probs  <- bundle$prob
preds  <- bundle$class

# ------------------------------------------------------------------------------
# 1. Model Accuracy Comparison Bar Chart
# ------------------------------------------------------------------------------
cat("Plotting [1/6] Model Accuracy Comparison...\n")
p1 <- ggplot(eval_df, aes(x = reorder(Model, Accuracy), y = Accuracy, fill = Accuracy)) +
  geom_bar(stat = "identity", width = 0.65, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.2f%%", Accuracy * 100)), hjust = -0.15, size = 3.8, fontface = "bold") +
  coord_flip() +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 0.70)) +
  scale_fill_gradient(low = "#4575b4", high = "#d73027") +
  theme_minimal(base_size = 13) +
  labs(
    title = "IPL Match Outcome Prediction: Model Accuracy Comparison",
    subtitle = "Evaluated on holdout test set (Seasons 2022-2024, N=218 matches)",
    x = "Algorithm",
    y = "Test Set Accuracy"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "gray30", size = 11),
    axis.text = element_text(color = "black", face = "bold"),
    panel.grid.minor = element_blank()
  )

ggsave("results/plots/model_accuracy_comparison.png", plot = p1, width = 9, height = 6, dpi = 300)

# ------------------------------------------------------------------------------
# 2. Precision, Recall, and F1 Score Comparison (Grouped Bar Chart)
# ------------------------------------------------------------------------------
cat("Plotting [2/6] Precision, Recall, and F1 Score Comparison...\n")
metrics_long <- eval_df %>%
  select(Model, Precision, Recall, F1) %>%
  pivot_longer(cols = c("Precision", "Recall", "F1"), names_to = "Metric", values_to = "Score")

p2 <- ggplot(metrics_long, aes(x = reorder(Model, Score), y = Score, fill = Metric)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.75), width = 0.7) +
  coord_flip() +
  scale_fill_manual(values = c("Precision" = "#2b83ba", "Recall" = "#fdae61", "F1" = "#d7191c")) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 0.65)) +
  theme_minimal(base_size = 13) +
  labs(
    title = "Comparative Performance Metrics: Precision, Recall & F1",
    subtitle = "12 Classification Models evaluated on holdout test data",
    x = "Algorithm",
    y = "Score",
    fill = "Metric"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "gray30", size = 11),
    legend.position = "top",
    axis.text = element_text(color = "black", face = "bold")
  )

ggsave("results/plots/metrics_comparison.png", plot = p2, width = 10, height = 7, dpi = 300)

# ------------------------------------------------------------------------------
# 3. Multi-Model ROC Curves
# ------------------------------------------------------------------------------
cat("Plotting [3/6] Multi-Model ROC Curves...\n")
roc_models <- c("Random Forest", "Extra Trees", "Bagging", "Decision Tree", "Logistic Regression", "Gradient Boosting")
roc_data_list <- list()

for (m in roc_models) {
  pr <- probs[[m]]
  roc_res <- pROC::roc(response = y_test, predictor = pr, quiet = TRUE)
  auc_val <- as.numeric(pROC::auc(roc_res))
  df_roc <- data.frame(
    FPR = 1 - roc_res$specificities,
    TPR = roc_res$sensitivities,
    Model_Label = sprintf("%s (AUC = %.3f)", m, auc_val)
  )
  roc_data_list[[m]] <- df_roc
}
roc_plot_df <- do.call(rbind, roc_data_list)

p3 <- ggplot(roc_plot_df, aes(x = FPR, y = TPR, color = Model_Label)) +
  geom_line(linewidth = 1.1) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray50", linewidth = 0.8) +
  scale_color_brewer(palette = "Set1") +
  theme_minimal(base_size = 13) +
  labs(
    title = "Receiver Operating Characteristic (ROC) Curves",
    subtitle = "Top Models Ranked by Discriminative Power on Test Matches",
    x = "False Positive Rate (1 - Specificity)",
    y = "True Positive Rate (Sensitivity)",
    color = "Model & AUC"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "gray30", size = 11),
    legend.position = c(0.72, 0.25),
    legend.background = element_rect(fill = "white", color = "gray80"),
    panel.grid.minor = element_blank()
  )

ggsave("results/roc_curves/roc_curves.png", plot = p3, width = 8, height = 7, dpi = 300)

# ------------------------------------------------------------------------------
# 4. Confusion Matrices for Top Models
# ------------------------------------------------------------------------------
cat("Plotting [4/6] Confusion Matrices for Representative Models...\n")
cm_models <- c("Decision Tree", "Gradient Boosting", "KNN", "Random Forest")
cm_list <- list()

for (m in cm_models) {
  yp <- preds[[m]]
  tbl <- table(Actual = factor(y_test, levels = c(0, 1), labels = c("Team 2 Won", "Team 1 Won")),
               Predicted = factor(yp, levels = c(0, 1), labels = c("Team 2 Won", "Team 1 Won")))
  df_cm <- as.data.frame(tbl)
  df_cm$Model <- m
  cm_list[[m]] <- df_cm
}
cm_df <- do.call(rbind, cm_list)

p4 <- ggplot(cm_df, aes(x = Predicted, y = Actual, fill = Freq)) +
  geom_tile(color = "white", linewidth = 1.2) +
  geom_text(aes(label = Freq), size = 6, fontface = "bold", color = "black") +
  scale_fill_gradient(low = "#e0f3f8", high = "#67a9cf") +
  facet_wrap(~ Model, ncol = 2) +
  theme_minimal(base_size = 12) +
  labs(
    title = "Test Set Confusion Matrices across Representative Classifiers",
    subtitle = "Actual vs Predicted Outcomes (N=218 test matches)",
    fill = "Match Count"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    strip.text = element_text(face = "bold", size = 12),
    axis.text = element_text(face = "bold", color = "black")
  )

ggsave("results/confusion_matrices/confusion_matrices.png", plot = p4, width = 8, height = 7, dpi = 300)

# ------------------------------------------------------------------------------
# 5. Feature Importance Plot (Explainability)
# ------------------------------------------------------------------------------
cat("Plotting [5/6] Explainable Feature Importance...\n")
p5 <- ggplot(importance_df, aes(x = reorder(Feature, RF_Gini_Importance), y = RF_Gini_Importance, fill = RF_Gini_Importance)) +
  geom_bar(stat = "identity", width = 0.65, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.1f", RF_Gini_Importance)), hjust = -0.15, size = 3.5, fontface = "bold") +
  coord_flip() +
  scale_fill_gradient(low = "#a6bddb", high = "#02818a") +
  scale_y_continuous(limits = c(0, max(importance_df$RF_Gini_Importance) * 1.15)) +
  theme_minimal(base_size = 13) +
  labs(
    title = "Feature Importance: Mean Decrease in Gini Impurity",
    subtitle = "Explainability analysis derived from trained ensemble model",
    x = "Feature",
    y = "Importance Score (Gini)"
  ) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(color = "gray30", size = 11),
    axis.text = element_text(color = "black", face = "bold"),
    panel.grid.minor = element_blank()
  )

ggsave("results/plots/feature_importance.png", plot = p5, width = 9, height = 6.5, dpi = 300)

# ------------------------------------------------------------------------------
# 6. Correlation Heatmap
# ------------------------------------------------------------------------------
cat("Plotting [6/6] Feature Correlation Heatmap...\n")
cor_data <- features_df[, c(selected_features, "team1_won")]
cor_mat <- cor(cor_data, use = "pairwise.complete.obs")

png("results/plots/correlation_heatmap.png", width = 2400, height = 2200, res = 300)
corrplot(cor_mat, method = "color", type = "upper", order = "hclust",
         tl.col = "black", tl.srt = 45, tl.cex = 0.75,
         addCoef.col = "black", number.cex = 0.55, number.digits = 2,
         col = colorRampPalette(c("#d73027", "#f7f7f7", "#4575b4"))(200),
         title = "IPL Feature Correlation Matrix & Target Alignment", mar = c(0,0,2,0))
dev.off()

cat("\nAll 6 comparative visualizations successfully generated in results/plots/, results/roc_curves/, and results/confusion_matrices/!\n")
cat("====================================================================\n\n")
