// ModelBreakdown.jsx — Per-model probability comparison
import React from 'react';
import './ModelBreakdown.css';

const MODEL_ICONS = {
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

export default function ModelBreakdown({ breakdown, consensus, team1, team2, benchmarks }) {
  if (!breakdown) return null;

  // Merge predictions with benchmark accuracy
  const entries = Object.entries(breakdown).map(([name, prob]) => {
    const bench = benchmarks?.find(b => b.Model === name);
    return {
      name,
      prob: Number(prob),
      accuracy: bench ? Number(bench.Accuracy) : null,
    };
  }).sort((a, b) => b.prob - a.prob);

  return (
    <div className="model-breakdown">
      {/* Consensus headline */}
      <div className="consensus-row">
        <div className="consensus-label">
          <span className="consensus-icon">🎯</span>
          <span>Multi-Model Consensus</span>
        </div>
        <div className="consensus-values">
          <span className="consensus-pct team1">{(consensus * 100).toFixed(1)}%</span>
          <span className="consensus-sep">/</span>
          <span className="consensus-pct team2">{((1 - consensus) * 100).toFixed(1)}%</span>
        </div>
      </div>

      <div className="divider" />

      {/* Per-model rows */}
      <div className="model-rows">
        {entries.map((m, idx) => {
          const t1Pct = m.prob * 100;
          const t2Pct = (1 - m.prob) * 100;
          const icon = MODEL_ICONS[m.name] || '🤖';
          const predicted = t1Pct >= 50 ? team1 : team2;

          return (
            <div key={m.name} className="model-row anim-fade-up" style={{ animationDelay: `${idx * 0.05}s` }}>
              <div className="model-row-left">
                <span className="model-icon">{icon}</span>
                <div>
                  <div className="model-name">{m.name}</div>
                  {m.accuracy && (
                    <div className="model-accuracy">Acc: {(m.accuracy * 100).toFixed(1)}%</div>
                  )}
                </div>
              </div>

              <div className="model-mini-bar-wrap">
                <span className="model-mini-pct left">{t1Pct.toFixed(0)}%</span>
                <div className="model-mini-bar">
                  <div
                    className="model-mini-fill t1"
                    style={{ width: `${t1Pct}%` }}
                  />
                </div>
                <span className="model-mini-pct right">{t2Pct.toFixed(0)}%</span>
              </div>

              <div className="model-pick">
                <span className={`model-pick-badge ${predicted === team1 ? 'team1' : 'team2'}`}>
                  {predicted === team1 ? team1.split(' ').pop() : team2.split(' ').pop()}
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
