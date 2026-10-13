// ModelLeaderboard.jsx — Full accuracy leaderboard from /api/models
import React from 'react';
import './ModelLeaderboard.css';

const ICONS = {
  'Logistic Regression': '📊',
  'Decision Tree': '🌳',
  'Random Forest': '🌲',
  'KNN': '🔵',
  'Naive Bayes': '📐',
  'SVM': '⚡',
  'AdaBoost': '🚀',
  'Gradient Boosting': '🔥',
  'MLP': '🧠',
};

const MEDAL = ['🥇', '🥈', '🥉'];

export default function ModelLeaderboard({ models }) {
  if (!models || models.length === 0) {
    return (
      <div className="text-muted text-sm" style={{ padding: '20px', textAlign: 'center' }}>
        Model benchmark data unavailable.
      </div>
    );
  }

  // Sort by Accuracy descending
  const sorted = [...models].sort((a, b) => Number(b.Accuracy) - Number(a.Accuracy));

  const metric = (val) => val != null ? (Number(val) * 100).toFixed(1) + '%' : '—';
  const metricRaw = (val) => val != null ? Number(val).toFixed(4) : '—';

  return (
    <div className="leaderboard">
      {/* Header */}
      <div className="leaderboard-header">
        <span className="lb-col-model">Model</span>
        <span className="lb-col-metric">Accuracy</span>
        <span className="lb-col-metric">F1</span>
        <span className="lb-col-metric">AUC-ROC</span>
        <span className="lb-col-bar">Performance</span>
      </div>

      {/* Rows */}
      {sorted.map((m, idx) => {
        const acc = Number(m.Accuracy || 0);
        const icon = ICONS[m.Model] || '🤖';
        const medal = MEDAL[idx] || '';

        return (
          <div
            key={m.Model}
            className={`lb-row anim-fade-up ${idx === 0 ? 'top' : ''}`}
            style={{ animationDelay: `${idx * 0.04}s` }}
          >
            <div className="lb-col-model">
              <span className="lb-rank">{medal || `#${idx + 1}`}</span>
              <span className="lb-icon">{icon}</span>
              <span className="lb-name">{m.Model}</span>
            </div>
            <span className="lb-col-metric lb-acc">{metric(m.Accuracy)}</span>
            <span className="lb-col-metric">{metricRaw(m.F1)}</span>
            <span className="lb-col-metric">{metricRaw(m.AUC_ROC || m['AUC-ROC'] || m.AUC)}</span>
            <div className="lb-col-bar">
              <div className="lb-bar-track">
                <div
                  className="lb-bar-fill"
                  style={{
                    width: `${Math.min(acc * 100, 100)}%`,
                    background: idx === 0
                      ? 'linear-gradient(90deg, var(--violet-500), var(--electric))'
                      : 'linear-gradient(90deg, var(--blue-500), var(--blue-400))',
                  }}
                />
              </div>
            </div>
          </div>
        );
      })}

      <div className="leaderboard-footer">
        <span className="text-xs text-muted">
          Evaluated on held-out test set · Zero target leakage · Pre-match features only
        </span>
      </div>
    </div>
  );
}
