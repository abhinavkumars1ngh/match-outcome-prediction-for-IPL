// ProbabilityBar.jsx — Animated win probability visualization
import React, { useEffect, useState } from 'react';
import './ProbabilityBar.css';

export default function ProbabilityBar({ team1, team2, team1Prob, team2Prob, predictedWinner, team1Color, team2Color }) {
  const [animated, setAnimated] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => setAnimated(true), 100);
    return () => clearTimeout(t);
  }, [team1Prob]);

  const t1Pct = animated ? team1Prob : 50;
  const t2Pct = animated ? team2Prob : 50;

  const winner1 = predictedWinner === team1;
  const winner2 = predictedWinner === team2;

  return (
    <div className="prob-bar-container">
      {/* Team Labels */}
      <div className="prob-labels">
        <div className={`prob-team-label ${winner1 ? 'winner' : ''}`} style={{ '--tc': team1Color || '#7c3aed' }}>
          <div className="prob-team-avatar" style={{ background: team1Color || '#7c3aed' }}>
            {team1.substring(0, 2).toUpperCase()}
          </div>
          <div>
            <div className="prob-team-name">{team1}</div>
            {winner1 && <div className="prob-winner-badge">🏆 Predicted Winner</div>}
          </div>
        </div>

        <div className="prob-center">
          <span className="prob-vs">VS</span>
        </div>

        <div className={`prob-team-label right ${winner2 ? 'winner' : ''}`} style={{ '--tc': team2Color || '#3b82f6' }}>
          <div>
            <div className="prob-team-name right">{team2}</div>
            {winner2 && <div className="prob-winner-badge right">🏆 Predicted Winner</div>}
          </div>
          <div className="prob-team-avatar" style={{ background: team2Color || '#3b82f6' }}>
            {team2.substring(0, 2).toUpperCase()}
          </div>
        </div>
      </div>

      {/* Main Bar */}
      <div className="prob-bar-wrapper">
        <div className="prob-bar">
          <div
            className="prob-fill team1-fill"
            style={{
              width: `${t1Pct}%`,
              background: `linear-gradient(90deg, ${team1Color || '#7c3aed'}, ${team1Color || '#7c3aed'}aa)`,
              transition: animated ? 'width 1.2s cubic-bezier(0.16, 1, 0.3, 1)' : 'none',
            }}
          />
          <div
            className="prob-fill team2-fill"
            style={{
              width: `${t2Pct}%`,
              background: `linear-gradient(90deg, ${team2Color || '#3b82f6'}aa, ${team2Color || '#3b82f6'})`,
              transition: animated ? 'width 1.2s cubic-bezier(0.16, 1, 0.3, 1)' : 'none',
            }}
          />
        </div>

        {/* Percentage labels on bar */}
        <div className="prob-percentages">
          <span className="prob-pct" style={{ color: team1Color || '#a855f7' }}>
            {t1Pct.toFixed(1)}%
          </span>
          <span className="prob-pct right" style={{ color: team2Color || '#60a5fa' }}>
            {t2Pct.toFixed(1)}%
          </span>
        </div>
      </div>

      {/* Confidence bar */}
      <div className="confidence-row">
        <span className="conf-label">Confidence</span>
        <div className="conf-bar-track">
          <div
            className="conf-bar-fill"
            style={{
              width: animated ? `${Math.abs(team1Prob - team2Prob)}%` : '0%',
              transition: animated ? 'width 1.4s 0.3s cubic-bezier(0.16, 1, 0.3, 1)' : 'none',
              background: `linear-gradient(90deg, ${winner1 ? (team1Color || '#7c3aed') : (team2Color || '#3b82f6')}, var(--electric))`,
            }}
          />
        </div>
        <span className="conf-value">{Math.abs(team1Prob - team2Prob).toFixed(1)}pp</span>
      </div>
    </div>
  );
}
