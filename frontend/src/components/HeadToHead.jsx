// HeadToHead.jsx — H2H stats and recent form
import React from 'react';
import './HeadToHead.css';

export default function HeadToHead({ data, team1, team2, team1Color, team2Color }) {
  if (!data) return null;
  const c = data.comparison;

  const formBadges = (results, color) =>
    results.map((r, i) => (
      <span
        key={i}
        className={`form-badge ${r === 'W' ? 'win' : 'loss'}`}
      >
        {r}
      </span>
    ));

  return (
    <div className="h2h-container">
      {/* Overall H2H Record */}
      <div className="h2h-record">
        <div className="h2h-team-block" style={{ '--tc': team1Color || '#7c3aed' }}>
          <div className="h2h-wins" style={{ color: team1Color || '#a855f7' }}>
            {c.team1_wins}
          </div>
          <div className="h2h-team-name">{team1}</div>
          <div className="h2h-pct">{c.team1_h2h_win_pct.toFixed(1)}%</div>
        </div>

        <div className="h2h-center">
          <div className="h2h-total">{c.total_h2h_matches}</div>
          <div className="h2h-total-label">matches</div>
        </div>

        <div className="h2h-team-block" style={{ '--tc': team2Color || '#3b82f6' }}>
          <div className="h2h-wins" style={{ color: team2Color || '#60a5fa' }}>
            {c.team2_wins}
          </div>
          <div className="h2h-team-name">{team2}</div>
          <div className="h2h-pct">{c.team2_h2h_win_pct.toFixed(1)}%</div>
        </div>
      </div>

      <div className="divider" />

      {/* Recent Form */}
      <div className="form-section">
        <div className="form-row">
          <span className="form-team-label">{team1}</span>
          <div className="form-badges">
            {Array.isArray(c.team1_recent_form)
              ? formBadges(c.team1_recent_form, team1Color)
              : <span className="text-muted text-sm">No recent data</span>
            }
          </div>
        </div>
        <div className="form-row">
          <span className="form-team-label">{team2}</span>
          <div className="form-badges">
            {Array.isArray(c.team2_recent_form)
              ? formBadges(c.team2_recent_form, team2Color)
              : <span className="text-muted text-sm">No recent data</span>
            }
          </div>
        </div>
      </div>

      {/* Recent Encounters */}
      {c.recent_encounters && c.recent_encounters.length > 0 && (
        <>
          <div className="divider" />
          <div className="encounters-section">
            <div className="encounters-title">Recent Encounters</div>
            {c.recent_encounters.map((enc, idx) => (
              <div key={idx} className="encounter-row anim-fade-up" style={{ animationDelay: `${idx * 0.05}s` }}>
                <div className="encounter-date">{enc.date} · S{enc.season}</div>
                <div className="encounter-venue">{enc.venue}</div>
                <div className={`encounter-winner ${enc.winner === team1 ? 'team1' : 'team2'}`}
                  style={{ color: enc.winner === team1 ? (team1Color || '#a855f7') : (team2Color || '#60a5fa') }}>
                  🏆 {enc.winner}
                </div>
                {enc.margin && <div className="encounter-margin">by {enc.margin}</div>}
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
