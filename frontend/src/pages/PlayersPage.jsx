// PlayersPage.jsx — Searchable Player Directory and Complete Career Profiles
import React, { useState, useEffect } from 'react';
import { api } from '../api';
import './PlayersPage.css';

export default function PlayersPage() {
  const [search, setSearch] = useState('');
  const [players, setPlayers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selectedPlayer, setSelectedPlayer] = useState(null);
  const [profileLoading, setProfileLoading] = useState(false);
  const [profileData, setProfileData] = useState(null);
  const [error, setError] = useState('');

  // Initial directory
  useEffect(() => {
    setLoading(true);
    api.players('', 30)
      .then((res) => {
        if (res?.players) setPlayers(res.players);
      })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  // Debounced search
  useEffect(() => {
    const handler = setTimeout(() => {
      setLoading(true);
      api.players(search, 30)
        .then((res) => {
          if (res?.players) setPlayers(res.players);
        })
        .catch((err) => setError(err.message))
        .finally(() => setLoading(false));
    }, 250);

    return () => clearTimeout(handler);
  }, [search]);

  const handleSelectPlayer = (name) => {
    setSelectedPlayer(name);
    setProfileLoading(true);
    setProfileData(null);
    api.playerProfile(name)
      .then((res) => setProfileData(res))
      .catch((err) => setError(err.message))
      .finally(() => setProfileLoading(false));
  };

  return (
    <div className="players-page">
      <div className="page-header">
        <h1 className="page-title">IPL Player Directory & Career Profiles</h1>
        <p className="page-subtitle">
          Search over 650+ cricketers who played in the IPL (2008–2024). Explore complete batting and bowling breakdowns.
        </p>
      </div>

      {/* Search Input Bar */}
      <div className="white-card player-search-card">
        <div className="search-input-wrap">
          <span className="search-icon">🔍</span>
          <input
            type="text"
            className="player-search-input"
            placeholder="Type player name (e.g. Virat Kohli, MS Dhoni, Rohit Sharma, Bumrah)..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button className="clear-btn" onClick={() => setSearch('')}>✕</button>
          )}
        </div>
      </div>

      {error && (
        <div className="error-box">
          <span>⚠️</span>
          <span>{error}</span>
        </div>
      )}

      {/* Directory View */}
      {!selectedPlayer && (
        <div className="players-directory-wrap">
          <div className="directory-header">
            <h3>IPL Players ({players.length} shown)</h3>
            {loading && <span className="searching-indicator">Searching…</span>}
          </div>

          <div className="players-grid">
            {players.map((p) => (
              <div
                key={p.player_name}
                className="player-card"
                onClick={() => handleSelectPlayer(p.player_name)}
              >
                <div className="player-avatar-circle">
                  <span>{p.player_name.substring(0, 2).toUpperCase()}</span>
                </div>
                <div className="player-card-info">
                  <div className="player-name">{p.player_name}</div>
                  <div className="player-stats-preview">
                    {p.total_runs > 0 && <span>🏏 {p.total_runs} runs</span>}
                    {p.total_wickets > 0 && <span>🎯 {p.total_wickets} wkts</span>}
                    <span>({p.matches} matches)</span>
                  </div>
                </div>
                <span className="view-arrow">→</span>
              </div>
            ))}
          </div>

          {!loading && players.length === 0 && (
            <div className="empty-state">
              <p>No players matched your search "{search}". Try another name.</p>
            </div>
          )}
        </div>
      )}

      {/* Player Profile Detail View */}
      {selectedPlayer && (
        <div className="player-profile-view">
          <button className="back-btn" onClick={() => setSelectedPlayer(null)}>
            ← Back to Player Search
          </button>

          {profileLoading && (
            <div className="loading-state">
              <div className="spinner" />
              <span>Fetching career statistics for {selectedPlayer}…</span>
            </div>
          )}

          {profileData && (
            <div className="profile-content">
              {/* Profile Banner */}
              <div className="profile-banner">
                <div className="profile-avatar-large">
                  {profileData.player.name.substring(0, 2).toUpperCase()}
                </div>
                <div className="profile-banner-info">
                  <h2>{profileData.player.name}</h2>
                  <div className="profile-teams">
                    <strong>Teams Represented:</strong>{' '}
                    {profileData.player.teams?.length > 0
                      ? profileData.player.teams.join(', ')
                      : 'IPL Historical Squads'}
                  </div>
                  {profileData.player.player_of_match_awards > 0 && (
                    <div className="potm-badge">
                      ⭐ {profileData.player.player_of_match_awards} Player of the Match Awards
                    </div>
                  )}
                </div>
              </div>

              {/* Batting Section */}
              <div className="profile-section-card white-card">
                <h3 className="section-title-bar">🏏 Career Batting Breakdown</h3>
                <div className="stats-row-grid">
                  <div className="stat-box">
                    <span className="val">{profileData.batting.runs}</span>
                    <span className="lbl">Total Runs</span>
                  </div>
                  <div className="stat-box">
                    <span className="val">{profileData.batting.matches}</span>
                    <span className="lbl">Matches</span>
                  </div>
                  <div className="stat-box">
                    <span className="val">{profileData.batting.average}</span>
                    <span className="lbl">Batting Avg</span>
                  </div>
                  <div className="stat-box">
                    <span className="val">{profileData.batting.strike_rate}</span>
                    <span className="lbl">Strike Rate</span>
                  </div>
                  <div className="stat-box">
                    <span className="val">{profileData.batting.highest_score}</span>
                    <span className="lbl">Highest Score</span>
                  </div>
                  <div className="stat-box">
                    <span className="val">{profileData.batting.fifties} / {profileData.batting.hundreds}</span>
                    <span className="lbl">50s / 100s</span>
                  </div>
                  <div className="stat-box">
                    <span className="val">{profileData.batting.fours} / {profileData.batting.sixes}</span>
                    <span className="lbl">4s / 6s</span>
                  </div>
                </div>
              </div>

              {/* Bowling Section */}
              {profileData.bowling.balls > 0 && (
                <div className="profile-section-card white-card">
                  <h3 className="section-title-bar">🎯 Career Bowling Breakdown</h3>
                  <div className="stats-row-grid">
                    <div className="stat-box">
                      <span className="val">{profileData.bowling.wickets}</span>
                      <span className="lbl">Wickets</span>
                    </div>
                    <div className="stat-box">
                      <span className="val">{profileData.bowling.overs}</span>
                      <span className="lbl">Overs</span>
                    </div>
                    <div className="stat-box">
                      <span className="val">{profileData.bowling.economy}</span>
                      <span className="lbl">Economy</span>
                    </div>
                    <div className="stat-box">
                      <span className="val">{profileData.bowling.average > 0 ? profileData.bowling.average : '—'}</span>
                      <span className="lbl">Bowling Avg</span>
                    </div>
                    <div className="stat-box">
                      <span className="val">{profileData.bowling.dot_balls}</span>
                      <span className="lbl">Dot Balls</span>
                    </div>
                    <div className="stat-box">
                      <span className="val">{profileData.bowling.runs_conceded}</span>
                      <span className="lbl">Runs Conceded</span>
                    </div>
                  </div>
                </div>
              )}

              {/* Team Results With This Player */}
              {profileData.team_results && (
                <div className="profile-section-card white-card team-results-section">
                  <div className="section-title-wrap">
                    <h3 className="section-title-bar">🏆 Team Results With This Player</h3>
                    <span className="formula-badge">
                      Formula: wins / (wins + losses) × 100 [decisive matches]
                    </span>
                  </div>

                  {/* Summary Metric Cards */}
                  <div className="team-results-summary-grid">
                    <div className="stat-box highlight-box">
                      <span className="val">{profileData.team_results.summary.win_percentage}%</span>
                      <span className="lbl">Team Win Rate With Player</span>
                      <span className="sub-note">
                        {profileData.team_results.summary.wins}W - {profileData.team_results.summary.losses}L
                        {profileData.team_results.summary.no_results > 0 && ` (${profileData.team_results.summary.no_results} NR)`}
                        {' '}in {profileData.team_results.summary.matches} matches
                      </span>
                    </div>

                    {profileData.team_results.summary.matches_without > 0 && (
                      <div className="stat-box">
                        <span className="val">{profileData.team_results.summary.win_percentage_without}%</span>
                        <span className="lbl">Team Win Rate Without Player</span>
                        <span className="sub-note">
                          {profileData.team_results.summary.wins_without}W - {profileData.team_results.summary.losses_without}L
                          {' '}in {profileData.team_results.summary.matches_without} matches
                        </span>
                      </div>
                    )}

                    {profileData.team_results.summary.matches_without > 0 && (
                      <div className="stat-box">
                        <span className={`val ${profileData.team_results.summary.diff_pct_points >= 0 ? 'text-positive' : 'text-negative'}`}>
                          {profileData.team_results.summary.diff_pct_points >= 0 ? `+${profileData.team_results.summary.diff_pct_points}` : profileData.team_results.summary.diff_pct_points}%
                        </span>
                        <span className="lbl">Impact Delta</span>
                        <span className="sub-note">Percentage-point diff</span>
                      </div>
                    )}
                  </div>

                  {/* Association Disclaimer Alert */}
                  <div className="association-disclaimer-note">
                    <span>ℹ️</span>
                    <span>{profileData.team_results.summary.association_disclaimer}</span>
                  </div>

                  {/* Season Breakdown Table */}
                  {profileData.team_results.seasons?.length > 0 && (
                    <div className="seasons-table-wrap">
                      <h4 className="table-heading">Season & Franchise Breakdown</h4>
                      <div className="table-responsive">
                        <table className="team-records-table">
                          <thead>
                            <tr>
                              <th>Franchise Team</th>
                              <th>Season</th>
                              <th>Matches With</th>
                              <th>Record (W-L-NR)</th>
                              <th>Win % With</th>
                              <th>Record Without</th>
                              <th>Win % Without</th>
                            </tr>
                          </thead>
                          <tbody>
                            {profileData.team_results.seasons.map((s, idx) => (
                              <tr key={`${s.team}-${s.season}-${idx}`}>
                                <td className="team-cell"><strong>{s.team}</strong></td>
                                <td>{s.season}</td>
                                <td>{s.matches}</td>
                                <td>{s.wins}W - {s.losses}L{s.no_results > 0 ? ` (${s.no_results} NR)` : ''}</td>
                                <td>
                                  <span className="win-pct-tag">{s.win_percentage}%</span>
                                </td>
                                <td>
                                  {s.has_without_data ? `${s.wins_without}W - ${s.losses_without}L` : '—'}
                                </td>
                                <td>
                                  {s.has_without_data && s.win_percentage_without !== null && !isNaN(s.win_percentage_without) ? (
                                    <span className="without-pct-tag">{s.win_percentage_without}%</span>
                                  ) : (
                                    <span className="text-muted">No Absences</span>
                                  )}
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  )}

                  {/* Participation Data Integrity & Scope Disclosure */}
                  <div className="data-limitation-box">
                    <strong>Participation Data Integrity Notice:</strong> {profileData.team_results.data_limitation}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
