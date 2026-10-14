// ModelLeaderboard.jsx — Enterprise algorithm benchmark leaderboard
import React from 'react';
import './ModelLeaderboard.css';

export default function ModelLeaderboard({ models }) {
  if (!models || models.length === 0) {
    return (
      <div className="text-muted text-sm" style={{ padding: '24px', textAlign: 'center' }}>
        Model benchmark data is currently loading or unavailable.
      </div>
    );
  }

  // Sort by Accuracy descending
  const sorted = [...models].sort((a, b) => Number(b.Accuracy || 0) - Number(a.Accuracy || 0));

  const metric = (val) => val != null ? (Number(val) * 100).toFixed(1) + '%' : '—';
  const metricRaw = (val) => val != null ? Number(val).toFixed(4) : '—';

  return (
    <div className="leaderboard">
      {/* Header */}
      <div className="leaderboard-header">
        <span className="lb-col-model">Classification Model</span>
        <span className="lb-col-metric">Accuracy</span>
        <span className="lb-col-metric">F1 Score</span>
        <span className="lb-col-metric">ROC-AUC</span>
        <span className="lb-col-bar">Test Accuracy Ratio</span>
      </div>

      {/* Rows */}
      {sorted.map((m, idx) => {
        const acc = Number(m.Accuracy || 0);
        const isTop = idx < 3;

        return (
          <div
            key={m.Model}
            className={`lb-row ${isTop ? 'top' : ''}`}
          >
            <div className="lb-col-model">
              <span className={`lb-rank-badge ${isTop ? 'top-rank' : ''}`}>
                #{idx + 1}
              </span>
              <span className="lb-name">{m.Model}</span>
              {idx === 0 && <span className="top-model-pill">Best Performer</span>}
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
                    backgroundColor: isTop ? '#15803d' : '#16a34a',
                  }}
                />
              </div>
            </div>
          </div>
        );
      })}

      <div className="leaderboard-footer">
        <span className="text-xs text-muted">
          Evaluated on held-out test matches (2022–2024) · Strict zero target leakage · Pre-match features only
        </span>
      </div>
    </div>
  );
}
