// StatsPage.jsx — Tournament Aggregates, Season Leaderboards & Record Summaries
import React, { useState, useEffect } from 'react';
import { api } from '../api';
import './StatsPage.css';

export default function StatsPage() {
  const [season, setSeason] = useState('');
  const [team, setTeam] = useState('');
  const [filters, setFilters] = useState({ available_seasons: [], available_teams: [] });
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const fetchStats = (s, t) => {
    setLoading(true);
    api.stats(s, t)
      .then((res) => {
        setData(res);
        if (res?.filters) setFilters(res.filters);
      })
      .catch((err) => setError(err.message || 'Failed to fetch tournament stats'))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    fetchStats('', '');
  }, []);

  const handleApplyFilter = () => {
    fetchStats(season, team);
  };

  const handleResetFilter = () => {
    setSeason('');
    setTeam('');
    fetchStats('', '');
  };

  return (
    <div className="stats-page">
      <div className="page-header">
        <h1 className="page-title">IPL Tournament Statistics & Leaderboards</h1>
        <p className="page-subtitle">
          Aggregate performance metrics, batting run leaders, and bowling wicket takers filterable by season and franchise.
        </p>
      </div>

      {/* Filter Bar */}
      <div className="white-card filter-bar">
        <div className="filter-group">
          <label className="form-label">Filter Season</label>
          <div className="select-wrapper">
            <select
              className="form-select"
              value={season}
              onChange={(e) => setSeason(e.target.value)}
            >
              <option value="">All 17 Seasons (2008–2024)</option>
              {filters.available_seasons?.map((s) => (
                <option key={s} value={s}>Season {s}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="filter-group">
          <label className="form-label">Filter Team</label>
          <div className="select-wrapper">
            <select
              className="form-select"
              value={team}
              onChange={(e) => setTeam(e.target.value)}
            >
              <option value="">All Teams</option>
              {filters.available_teams?.map((t) => (
                <option key={t} value={t}>{t}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="filter-actions">
          <button className="btn-primary" onClick={handleApplyFilter}>
            Apply Filters
          </button>
          {(season || team) && (
            <button className="btn-secondary" onClick={handleResetFilter}>
              Reset
            </button>
          )}
        </div>
      </div>

      {loading && (
        <div className="loading-state">
          <div className="spinner" />
          <span>Aggregating delivery & match records…</span>
        </div>
      )}

      {error && (
        <div className="error-box">
          <span>⚠️</span>
          <span>{error}</span>
        </div>
      )}

      {/* Summary Cards */}
      {data && data.summary && (
        <div className="stats-summary-strip">
          <div className="summary-pill">
            <span className="pill-val">{data.summary[0]?.matches_count}</span>
            <span className="pill-lbl">Matches Analyzed</span>
          </div>
          <div className="summary-pill">
            <span className="pill-val">{data.summary[0]?.seasons_count}</span>
            <span className="pill-lbl">Seasons</span>
          </div>
          <div className="summary-pill">
            <span className="pill-val">{data.summary[0]?.venues_count}</span>
            <span className="pill-lbl">Venues</span>
          </div>
        </div>
      )}

      {/* Leaderboard Tables */}
      {data && (
        <div className="leaderboards-grid">
          {/* Top Batsmen */}
          <div className="white-card leaderboard-card">
            <h3 className="card-title">🏏 Top Run Scorers</h3>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Rank</th>
                  <th>Batter</th>
                  <th>Matches</th>
                  <th>Runs</th>
                  <th>Strike Rate</th>
                </tr>
              </thead>
              <tbody>
                {data.top_run_scorers?.map((b, idx) => (
                  <tr key={b.batter}>
                    <td>#{idx + 1}</td>
                    <td><strong>{b.batter}</strong></td>
                    <td>{b.matches}</td>
                    <td><span className="score-highlight">{b.runs}</span></td>
                    <td>{b.strike_rate}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Top Bowlers */}
          <div className="white-card leaderboard-card">
            <h3 className="card-title">🎯 Top Wicket Takers</h3>
            <table className="data-table">
              <thead>
                <tr>
                  <th>Rank</th>
                  <th>Bowler</th>
                  <th>Matches</th>
                  <th>Wickets</th>
                  <th>Economy</th>
                </tr>
              </thead>
              <tbody>
                {data.top_wicket_takers?.map((w, idx) => (
                  <tr key={w.bowler}>
                    <td>#{idx + 1}</td>
                    <td><strong>{w.bowler}</strong></td>
                    <td>{w.matches}</td>
                    <td><span className="wicket-highlight">{w.wickets}</span></td>
                    <td>{w.economy > 0 ? w.economy : '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
