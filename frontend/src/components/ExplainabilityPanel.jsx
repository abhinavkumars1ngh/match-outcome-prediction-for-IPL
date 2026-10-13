// ExplainabilityPanel.jsx — XAI factor cards
import React from 'react';
import './ExplainabilityPanel.css';

function FactorBar({ val, maxVal = 100, color }) {
  return (
    <div className="factor-bar-track">
      <div
        className="factor-bar-fill"
        style={{
          width: `${Math.min((val / maxVal) * 100, 100)}%`,
          background: color,
        }}
      />
    </div>
  );
}

export default function ExplainabilityPanel({ xai, team1, team2, features, team1Color, team2Color }) {
  if (!xai) return null;

  const { venue_impact, h2h_impact, form_impact, toss_impact } = xai;

  const t1c = team1Color || '#a855f7';
  const t2c = team2Color || '#60a5fa';

  const factorCards = [
    {
      icon: '🏟️',
      label: venue_impact.name,
      detail: `${team1}: ${venue_impact.team1_val}% · ${team2}: ${venue_impact.team2_val}%`,
      advantage: venue_impact.advantage,
      bars: [
        { label: team1, val: venue_impact.team1_val, color: t1c },
        { label: team2, val: venue_impact.team2_val, color: t2c },
      ],
    },
    {
      icon: '⚔️',
      label: h2h_impact.name,
      detail: `${team1}: ${h2h_impact.team1_val}% · ${team2}: ${h2h_impact.team2_val}%`,
      advantage: h2h_impact.advantage,
      bars: [
        { label: team1, val: h2h_impact.team1_val, color: t1c },
        { label: team2, val: h2h_impact.team2_val, color: t2c },
      ],
    },
    {
      icon: '📈',
      label: form_impact.name,
      detail: `${team1}: ${form_impact.team1_val} · ${team2}: ${form_impact.team2_val}`,
      advantage: form_impact.advantage,
      bars: null, // text-only
    },
    {
      icon: '🪙',
      label: toss_impact.name,
      detail: toss_impact.detail,
      extra: `Venue toss→win rate: ${toss_impact.venue_toss_win_pct}%`,
      advantage: toss_impact.advantage,
      bars: null,
    },
  ];

  return (
    <div className="xai-container">
      <div className="xai-grid">
        {factorCards.map((card, idx) => {
          const isTeam1Adv = card.advantage === team1;
          const isTeam2Adv = card.advantage === team2;
          const advColor = isTeam1Adv ? t1c : isTeam2Adv ? t2c : 'rgba(148,163,184,0.6)';
          const advLabel = isTeam1Adv
            ? team1.split(' ').pop()
            : isTeam2Adv
            ? team2.split(' ').pop()
            : card.advantage;

          return (
            <div key={idx} className="xai-card anim-fade-up" style={{ animationDelay: `${idx * 0.07}s` }}>
              <div className="xai-card-header">
                <span className="xai-icon">{card.icon}</span>
                <div>
                  <div className="xai-label">{card.label}</div>
                  <div className="xai-detail">{card.detail}</div>
                  {card.extra && <div className="xai-detail">{card.extra}</div>}
                </div>
              </div>
              {card.bars && (
                <div className="xai-bars">
                  {card.bars.map((b, bi) => (
                    <div key={bi} className="xai-bar-row">
                      <span className="xai-bar-label">{b.label.split(' ').pop()}</span>
                      <FactorBar val={b.val} maxVal={100} color={b.color} />
                      <span className="xai-bar-val">{b.val}%</span>
                    </div>
                  ))}
                </div>
              )}
              <div className="xai-advantage" style={{ '--adv-c': advColor }}>
                <span className="xai-adv-dot" />
                <span className="xai-adv-label">Advantage:</span>
                <span className="xai-adv-team">{advLabel}</span>
              </div>
            </div>
          );
        })}
      </div>

      {/* Feature Values */}
      {features && (
        <div className="feature-values-section">
          <div className="feature-values-title">Computed Pre-Match Features</div>
          <div className="feature-values-grid">
            {Object.entries(features).map(([key, val]) => (
              <div key={key} className="feature-item">
                <span className="feature-key">{key.replace(/_/g, ' ')}</span>
                <span className="feature-val">{typeof val === 'number' ? val.toFixed(4) : String(val)}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
