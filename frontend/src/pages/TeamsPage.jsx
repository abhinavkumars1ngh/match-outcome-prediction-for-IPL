// TeamsPage.jsx — Team Directory & Detailed Franchise Analytics
import React, { useState, useEffect } from 'react';
import { api } from '../api';
import './TeamsPage.css';

export default function TeamsPage({ onSelectForPredict }) {
  const [teams, setTeams] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedTeam, setSelectedTeam] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailData, setDetailData] = useState(null);

  useEffect(() => {
    api.teams()
      .then((res) => {
        if (res?.teams) setTeams(res.teams);
      })
      .catch((err) => setError(err.message || 'Failed to load teams.'))
      .finally(() => setLoading(false));
  }, []);

  const handleTeamClick = (teamName) => {
    setSelectedTeam(teamName);
    setDetailLoading(true);
    setDetailData(null);
    api.teamDetail(teamName)
      .then((data) => setDetailData(data))
      .catch((err) => setError(err.message))
      .finally(() => setDetailLoading(false));
  };

  return (
    <div className="teams-page">
      <div className="page-header">
        <div>
          <h1 className="page-title">IPL Franchises & Team Records</h1>
          <p className="page-subtitle">
            Historical tournament records, win rates, and ground performances across all 17 IPL seasons.
          </p>
        </div>
      </div>

      {loading && (
        <div className="loading-state">
          <div className="spinner" />
          <span>Loading teams archive…</span>
        </div>
      )}

      {error && (
        <div className="error-box">
          <span>⚠️</span>
          <span>{error}</span>
        </div>
      )}

      {/* Grid of Teams */}
      {!loading && !selectedTeam && (
        <div className="teams-grid">
          {teams.map((t) => (
            <div
              key={t.name}
              className="team-overview-card"
              onClick={() => handleTeamClick(t.name)}
              style={{ '--team-accent': t.primary_color }}
            >
              <div className="team-header-row">
                <div className="team-avatar-box" style={{ background: t.primary_color }}>
                  <span>{t.short_name || t.name.substring(0, 3).toUpperCase()}</span>
                </div>
                <div className="team-name-box">
                  <div className="team-card-name">{t.name}</div>
                  <div className="team-card-abbr">{t.short_name}</div>
                </div>
              </div>

              <div className="team-card-stats">
                <div className="team-stat-col">
                  <span className="stat-label">Matches</span>
                  <span className="stat-val">{t.matches_played}</span>
                </div>
                <div className="team-stat-col">
                  <span className="stat-label">Wins</span>
                  <span className="stat-val">{t.wins}</span>
                </div>
                <div className="team-stat-col">
                  <span className="stat-label">Win Rate</span>
                  <span className="stat-val win-pct">{t.win_percentage}%</span>
                </div>
                <div className="team-stat-col">
                  <span className="stat-label">Titles</span>
                  <span className="stat-val">{t.titles > 0 ? `🏆 ${t.titles}` : '—'}</span>
                </div>
              </div>

              <div className="team-card-footer">
                <span>View Complete Performance Profile →</span>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Team Detail View */}
      {selectedTeam && (
        <div className="team-detail-view">
          <button className="back-btn" onClick={() => setSelectedTeam(null)}>
            ← Back to All Teams
          </button>

          {detailLoading && (
            <div className="loading-state">
              <div className="spinner" />
              <span>Loading detailed statistics for {selectedTeam}…</span>
            </div>
          )}

          {detailData && (
            <div className="detail-content">
              {/* Header card */}
              <div className="detail-banner" style={{ borderLeft: `6px solid ${detailData.team.primary_color || '#15803d'}` }}>
                <div className="detail-banner-main">
                  <h2>{detailData.team.name}</h2>
                  <div className="detail-tags">
                    <span className="detail-tag">{detailData.team.short_name}</span>
                    {detailData.team.titles > 0 && <span className="detail-tag title-tag">🏆 {detailData.team.titles} IPL Titles</span>}
                  </div>
                </div>
                {onSelectForPredict && (
                  <button
                    className="btn-primary"
                    onClick={() => onSelectForPredict(detailData.team)}
                  >
                    🔮 Predict Next Match
                  </button>
                )}
              </div>

              {/* Summary Metrics */}
              <div className="summary-grid">
                <div className="summary-card">
                  <div className="summary-num">{detailData.summary.matches}</div>
                  <div className="summary-lbl">Total Matches</div>
                </div>
                <div className="summary-card">
                  <div className="summary-num">{detailData.summary.wins}</div>
                  <div className="summary-lbl">Wins</div>
                </div>
                <div className="summary-card">
                  <div className="summary-num">{detailData.summary.losses}</div>
                  <div className="summary-lbl">Losses</div>
                </div>
                <div className="summary-card highlight">
                  <div className="summary-num">{detailData.summary.win_pct}%</div>
                  <div className="summary-lbl">Win Percentage</div>
                </div>
                <div className="summary-card">
                  <div className="summary-num">{detailData.summary.batting_first.win_pct}%</div>
                  <div className="summary-lbl">Defending ({detailData.summary.batting_first.wins}/{detailData.summary.batting_first.played})</div>
                </div>
                <div className="summary-card">
                  <div className="summary-num">{detailData.summary.chasing.win_pct}%</div>
                  <div className="summary-lbl">Chasing ({detailData.summary.chasing.wins}/{detailData.summary.chasing.played})</div>
                </div>
              </div>

              <div className="detail-tables-grid">
                {/* Season-by-Season Table */}
                <div className="white-card detail-table-card">
                  <h3 className="card-title">📅 Season-by-Season Trajectory</h3>
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>Season</th>
                        <th>Matches</th>
                        <th>Wins</th>
                        <th>Win Rate</th>
                      </tr>
                    </thead>
                    <tbody>
                      {detailData.seasons.map((s) => (
                        <tr key={s.season}>
                          <td><strong>{s.season}</strong></td>
                          <td>{s.played}</td>
                          <td>{s.wins}</td>
                          <td><strong>{((s.wins / s.played) * 100).toFixed(1)}%</strong></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {/* Head-to-Head Opponents */}
                <div className="white-card detail-table-card">
                  <h3 className="card-title">⚔️ Records vs Opponents</h3>
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>Opponent</th>
                        <th>Played</th>
                        <th>Wins</th>
                        <th>Win %</th>
                      </tr>
                    </thead>
                    <tbody>
                      {detailData.head_to_head.map((h) => (
                        <tr key={h.opponent}>
                          <td><strong>{h.opponent}</strong></td>
                          <td>{h.played}</td>
                          <td>{h.wins}</td>
                          <td><strong>{((h.wins / h.played) * 100).toFixed(1)}%</strong></td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
