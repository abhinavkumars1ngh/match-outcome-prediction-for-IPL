// My11Page.jsx — Build Your Playing XI & Defensible Team Win Estimation
import React, { useState, useEffect } from 'react';
import { api } from '../api';
import './My11Page.css';

export default function My11Page() {
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [searching, setSearching] = useState(false);
  const [roleFilter, setRoleFilter] = useState('All');

  // Venue and Opponent selectors for Part C enhancements
  const [venues, setVenues] = useState([]);
  const [teams, setTeams] = useState([]);
  const [selectedVenue, setSelectedVenue] = useState('');
  const [selectedOpponent, setSelectedOpponent] = useState('');

  // Selected XI: Array of player objects { name, role, derived_role, runs, wickets, matches, is_user_assigned }
  const [selectedPlayers, setSelectedPlayers] = useState([]);
  const [customRoles, setCustomRoles] = useState({});

  // Calculation Results
  const [calculating, setCalculating] = useState(false);
  const [calcResult, setCalcResult] = useState(null);
  const [calcError, setCalcError] = useState('');

  // Fetch candidate list on search or role filter change
  useEffect(() => {
    const timer = setTimeout(() => {
      setSearching(true);
      api.players(searchTerm, 40, roleFilter)
        .then((res) => {
          if (res?.players) setSearchResults(res.players);
        })
        .catch(() => {})
        .finally(() => setSearching(false));
    }, 200);

    return () => clearTimeout(timer);
  }, [searchTerm, roleFilter]);

  // Load venues and teams on mount
  useEffect(() => {
    Promise.all([api.venues(), api.teams()])
      .then(([vRes, tRes]) => {
        if (vRes?.venues) setVenues(vRes.venues);
        if (tRes?.teams) setTeams(tRes.teams);
      })
      .catch((e) => console.error('Failed to load venue/team metadata:', e));
  }, []);

  // Role Counts & Live Validation
  const countBatsmen = selectedPlayers.filter((p) => (customRoles[p.player_name] || p.role) === 'Batsman').length;
  const countAllRounders = selectedPlayers.filter((p) => (customRoles[p.player_name] || p.role) === 'All-Rounder').length;
  const countBowlers = selectedPlayers.filter((p) => (customRoles[p.player_name] || p.role) === 'Bowler').length;

  const reqBatsmenMet = countBatsmen >= 2;
  const reqAllRoundersMet = countAllRounders >= 1;
  const reqBowlersMet = countBowlers >= 5;
  const reqCountMet = selectedPlayers.length === 11;
  const isValidXI = reqBatsmenMet && reqAllRoundersMet && reqBowlersMet && reqCountMet;

  // Add Player to XI
  const handleAddPlayer = (p) => {
    if (selectedPlayers.length >= 11) return;
    if (selectedPlayers.some((item) => item.player_name === p.player_name)) return;

    setSelectedPlayers([...selectedPlayers, p]);
    setCalcResult(null); // invalidate previous calculation
  };

  // Remove Player
  const handleRemovePlayer = (pName) => {
    setSelectedPlayers(selectedPlayers.filter((item) => item.player_name !== pName));
    const nextRoles = { ...customRoles };
    delete nextRoles[pName];
    setCustomRoles(nextRoles);
    setCalcResult(null);
  };

  // Change Player Role (User-Assigned Role)
  const handleChangeRole = (pName, newRole) => {
    setCustomRoles((prev) => ({
      ...prev,
      [pName]: newRole,
    }));
    setCalcResult(null);
  };

  // Reset XI
  const handleClearXI = () => {
    setSelectedPlayers([]);
    setCustomRoles({});
    setCalcResult(null);
    setCalcError('');
  };

  // Quick Preset Sample XI (RCB 2024 verified XI)
  const handleLoadSampleXI = () => {
    setSearching(true);
    const sampleNames = [
      'V Kohli', 'F du Plessis', 'GJ Maxwell', 'KD Karthik', 'RM Patidar',
      'C Green', 'Swapnil Singh', 'KV Sharma', 'Mohammed Siraj', 'Yash Dayal', 'LH Ferguson'
    ];

    Promise.all(sampleNames.map((name) => api.players(name, 1)))
      .then((results) => {
        const loaded = results.map((res, i) => {
          if (res?.players?.length > 0) return res.players[0];
          return { player_name: sampleNames[i], role: i >= 6 ? 'Bowler' : (i === 2 || i === 5 ? 'All-Rounder' : 'Batsman'), total_runs: 0, total_wickets: 0, matches: 0 };
        });
        setSelectedPlayers(loaded);
        setCustomRoles({ 'Swapnil Singh': 'Bowler' }); // Satisfies >= 5 bowlers
        setCalcResult(null);
      })
      .catch(() => {})
      .finally(() => setSearching(false));
  };

  // Calculate Win Metrics with Venue & Opponent
  const handleCalculate = async () => {
    if (!isValidXI) return;
    setCalculating(true);
    setCalcError('');
    setCalcResult(null);

    try {
      const payload = {
        players: selectedPlayers.map((p) => p.player_name),
        roles: customRoles,
        venue: selectedVenue,
        opponent: selectedOpponent,
      };
      const res = await api.my11(payload);
      setCalcResult(res);
    } catch (err) {
      setCalcError(err.message || 'Failed to compute lineup metrics.');
    } finally {
      setCalculating(false);
    }
  };

  // Filter Search Candidates
  const filteredCandidates = searchResults.filter((p) => {
    if (roleFilter === 'All') return true;
    return p.role === roleFilter;
  });

  return (
    <div className="my11-page">
      {/* Header */}
      <div className="page-header">
        <div className="header-badge-row">
          <span className="section-pill">SQUAD ARCHITECT</span>
          <span className="section-pill-gold">VENUE & OPPONENT SUITABILITY</span>
        </div>
        <h1 className="page-title">MY11 — Build Your Playing XI</h1>
        <p className="page-subtitle">
          Construct an 11-player lineup from 730+ historical cricketers. Test squad balance against specific grounds and opponents with zero synthetic score fabrication.
        </p>
      </div>

      {/* Main Split Layout */}
      <div className="my11-layout-grid">
        {/* Left Column: Player Search & Pool */}
        <div className="my11-pool-column">
          <div className="white-card pool-card">
            <div className="card-header-row">
              <h3>🔍 Player Selection Pool</h3>
              <button className="sample-btn" onClick={handleLoadSampleXI} title="Load real RCB 2024 verified playing XI">
                Load Sample XI
              </button>
            </div>

            {/* Search Input */}
            <div className="pool-search-input-wrap">
              <input
                type="text"
                className="pool-search-input"
                placeholder="Search players by name (e.g. Dhoni, Kohli, Bumrah, Russell)..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
              {searchTerm && (
                <button className="clear-btn" onClick={() => setSearchTerm('')}>✕</button>
              )}
            </div>

            {/* Role Filter Tabs */}
            <div className="role-filter-tabs">
              {['All', 'Batsman', 'All-Rounder', 'Bowler'].map((r) => (
                <button
                  key={r}
                  className={`role-tab-btn ${roleFilter === r ? 'active' : ''}`}
                  onClick={() => setRoleFilter(r)}
                >
                  {r === 'All' ? 'All Roles' : r}
                </button>
              ))}
            </div>

            {/* Candidates List */}
            <div className="candidates-list">
              {filteredCandidates.map((p) => {
                const isSelected = selectedPlayers.some((item) => item.player_name === p.player_name);
                return (
                  <div
                    key={p.player_name}
                    className={`candidate-item ${isSelected ? 'already-selected' : ''}`}
                    onClick={() => !isSelected && handleAddPlayer(p)}
                  >
                    <div className="cand-avatar">
                      {p.player_name.substring(0, 2).toUpperCase()}
                    </div>
                    <div className="cand-info">
                      <div className="cand-name-row">
                        <span className="cand-name">{p.player_name}</span>
                        <span className={`cand-role-badge role-${p.role?.toLowerCase()?.replace(/\s+/g, '-')}`}>
                          {p.role}
                        </span>
                      </div>
                      <div className="cand-meta">
                        {p.total_runs > 0 && <span>🏏 {p.total_runs} r</span>}
                        {p.total_wickets > 0 && <span>🎯 {p.total_wickets} w</span>}
                        <span>({p.matches} m)</span>
                      </div>
                    </div>
                    <button
                      className={`add-player-btn ${isSelected ? 'disabled' : ''}`}
                      disabled={isSelected || selectedPlayers.length >= 11}
                      onClick={(e) => {
                        e.stopPropagation();
                        handleAddPlayer(p);
                      }}
                    >
                      {isSelected ? '✓ In XI' : '+ Add'}
                    </button>
                  </div>
                );
              })}

              {!searching && filteredCandidates.length === 0 && (
                <div className="empty-pool-state">
                  No cricketers matched "{searchTerm}".
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Right Column: Selected XI & Live Validation */}
        <div className="my11-roster-column">
          <div className="white-card roster-card">
            <div className="roster-header-row">
              <div>
                <h3 className="roster-title">
                  My Playing XI ({selectedPlayers.length} / 11)
                </h3>
                <span className="roster-sub">
                  Exactly 11 unique players required
                </span>
              </div>
              {selectedPlayers.length > 0 && (
                <button className="clear-all-btn" onClick={handleClearXI}>
                  Clear All
                </button>
              )}
            </div>

            {/* Match Context: Venue and Opponent */}
            <div className="roster-match-context">
              <div className="context-select-box">
                <label className="context-label">🏟️ Match Venue</label>
                <select
                  className="context-select"
                  value={selectedVenue}
                  onChange={(e) => {
                    setSelectedVenue(e.target.value);
                    setCalcResult(null);
                  }}
                >
                  <option value="">All Grounds Combined</option>
                  {venues.map((v) => (
                    <option key={v.venue} value={v.venue}>{v.venue} ({v.city})</option>
                  ))}
                </select>
              </div>

              <div className="context-select-box">
                <label className="context-label">🛡️ Target Opponent</label>
                <select
                  className="context-select"
                  value={selectedOpponent}
                  onChange={(e) => {
                    setSelectedOpponent(e.target.value);
                    setCalcResult(null);
                  }}
                >
                  <option value="">All Opponents Combined</option>
                  {teams.map((t) => (
                    <option key={t.name} value={t.name}>{t.name}</option>
                  ))}
                </select>
              </div>
            </div>

            {/* Live Requirements Checklist */}
            <div className="requirements-checklist">
              <div className={`req-item ${reqCountMet ? 'met' : 'unmet'}`}>
                <span className="req-icon">{reqCountMet ? '✓' : '○'}</span>
                <span>Squad: <strong>{selectedPlayers.length}/11</strong> players</span>
              </div>
              <div className={`req-item ${reqBatsmenMet ? 'met' : 'unmet'}`}>
                <span className="req-icon">{reqBatsmenMet ? '✓' : '○'}</span>
                <span>Batsmen: <strong>{countBatsmen}</strong> (min 2)</span>
              </div>
              <div className={`req-item ${reqAllRoundersMet ? 'met' : 'unmet'}`}>
                <span className="req-icon">{reqAllRoundersMet ? '✓' : '○'}</span>
                <span>All-Rounders: <strong>{countAllRounders}</strong> (min 1)</span>
              </div>
              <div className={`req-item ${reqBowlersMet ? 'met' : 'unmet'}`}>
                <span className="req-icon">{reqBowlersMet ? '✓' : '○'}</span>
                <span>Bowlers: <strong>{countBowlers}</strong> (min 5)</span>
              </div>
            </div>

            {/* Selected XI Players List */}
            <div className="selected-players-list">
              {selectedPlayers.map((p, idx) => {
                const currentRole = customRoles[p.player_name] || p.role;
                const isCustom = Boolean(customRoles[p.player_name] && customRoles[p.player_name] !== p.role);

                return (
                  <div key={p.player_name} className="selected-player-row">
                    <span className="player-order-num">{idx + 1}</span>
                    <div className="sel-player-name-wrap">
                      <span className="sel-name">{p.player_name}</span>
                      {isCustom && <span className="user-role-tag">user-selected</span>}
                    </div>

                    {/* Role Selector Dropdown */}
                    <div className="sel-role-dropdown-wrap">
                      <select
                        className="role-select"
                        value={currentRole}
                        onChange={(e) => handleChangeRole(p.player_name, e.target.value)}
                        title="Assign verified role or adjust for team balance"
                      >
                        <option value="Batsman">Batsman</option>
                        <option value="All-Rounder">All-Rounder</option>
                        <option value="Bowler">Bowler</option>
                      </select>
                    </div>

                    {/* Remove Action */}
                    <button
                      className="remove-player-btn"
                      onClick={() => handleRemovePlayer(p.player_name)}
                      title="Remove from Playing XI"
                    >
                      ✕
                    </button>
                  </div>
                );
              })}

              {selectedPlayers.length === 0 && (
                <div className="empty-roster-placeholder">
                  <span className="placeholder-icon">🏏</span>
                  <p>Your Playing XI is currently empty.</p>
                  <p className="placeholder-sub">
                    Select players from the pool on the left, or click <strong>Load Sample XI</strong> to test a verified lineup.
                  </p>
                </div>
              )}
            </div>

            {/* Calculate Button */}
            <div className="calculate-action-wrap">
              <button
                className={`calc-submit-btn ${!isValidXI || calculating ? 'disabled' : ''}`}
                disabled={!isValidXI || calculating}
                onClick={handleCalculate}
              >
                {calculating ? 'Analyzing Historical Lineups & Matchups…' : 'Calculate Lineup & Balance Suitability'}
              </button>
              {!isValidXI && (
                <div className="validation-helper-msg">
                  Ensure exactly 11 players are selected meeting all 3 role minimums (2+ Batsmen, 1+ All-Rounder, 5+ Bowlers).
                </div>
              )}
            </div>

            {calcError && (
              <div className="error-box my11-error">
                <span>⚠️</span>
                <span>{calcError}</span>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Results Panel */}
      {calcResult && (
        <div className="white-card my11-results-card">
          <div className="results-header-banner">
            <div>
              <span className="result-method-tag">
                {calcResult.methodology_statement.chosen_method}
              </span>
              <h2>Team Win Percentage & Squad Analysis</h2>
            </div>
            <button className="recalc-btn" onClick={handleCalculate} disabled={calculating}>
              🔄 Re-run Calculation
            </button>
          </div>

          {/* Primary Metric Hero Card */}
          <div className="results-primary-metrics-grid">
            {calcResult.method_a_exact_xi?.available ? (
              <div className="metric-callout-card exact-highlight">
                <span className="metric-badge">Method A — Exact Historical XI</span>
                <div className="big-stat-val">
                  {calcResult.method_a_exact_xi.summary.win_percentage}%
                </div>
                <div className="metric-label">Defensible Historical Win Rate</div>
                <div className="metric-subnote">
                  Record: <strong>{calcResult.method_a_exact_xi.summary.wins}W</strong> - <strong>{calcResult.method_a_exact_xi.summary.losses}L</strong>
                  {calcResult.method_a_exact_xi.summary.no_results > 0 && ` (${calcResult.method_a_exact_xi.summary.no_results} NR)`}
                  {' '}in {calcResult.method_a_exact_xi.summary.matches} verified fixtures
                </div>
              </div>
            ) : (
              <div className="metric-callout-card aggregate-highlight">
                <span className="metric-badge">Method B — Teammate Combination History</span>
                <div className="big-stat-val">
                  {calcResult.method_b_aggregate_history.win_percentage !== null
                    ? `${calcResult.method_b_aggregate_history.win_percentage}%`
                    : 'N/A'}
                </div>
                <div className="metric-label">Shared Franchise Fixtures Win Rate</div>
                <div className="metric-subnote">
                  Record: <strong>{calcResult.method_b_aggregate_history.wins}W</strong> - <strong>{calcResult.method_b_aggregate_history.losses}L</strong>
                  {' '}across {calcResult.method_b_aggregate_history.qualifying_matches} matches with &ge; 3 selected teammates together
                </div>
              </div>
            )}

            {/* PART C: Squad Balance Suitability Score (0-100) */}
            {calcResult.squad_balance && (
              <div className="metric-callout-card squad-balance-highlight">
                <span className="metric-badge">Transparent Squad Balance Score</span>
                <div className="big-stat-val highlight-green">
                  {calcResult.squad_balance.score ?? calcResult.squad_balance.total_score ?? '—'} <span className="denom">/ 100</span>
                </div>
                <div className="metric-label">Lineup Balance: <strong>{calcResult.squad_balance.rating || 'Standard'}</strong></div>
                {calcResult.squad_balance.components && (
                  <div className="balance-breakdown-chips">
                    <span>Bat: {calcResult.squad_balance.components.batting_depth?.score ?? 0}/{calcResult.squad_balance.components.batting_depth?.max ?? 25}</span>
                    <span>Bowl: {calcResult.squad_balance.components.bowling_options?.score ?? 0}/{calcResult.squad_balance.components.bowling_options?.max ?? 30}</span>
                    <span>AR: {calcResult.squad_balance.components.all_rounder_coverage?.score ?? 0}/{calcResult.squad_balance.components.all_rounder_coverage?.max ?? 20}</span>
                    <span>Exp: {calcResult.squad_balance.components.collective_experience?.score ?? 0}/{calcResult.squad_balance.components.collective_experience?.max ?? 25}</span>
                  </div>
                )}
              </div>
            )}

            <div className="metric-callout-card">
              <span className="metric-badge">Sample Size & Data Scope</span>
              <div className="sample-val-text">
                {calcResult.methodology_statement.sample_size_assessment}
              </div>
              <div className="metric-label">Official Match Evidence</div>
              <div className="metric-subnote">
                {calcResult.methodology_statement.data_scope}
              </div>
            </div>
          </div>

          {/* Contextual Stadium & Opponent Overview (Part C) */}
          {(calcResult.context_records?.venue || calcResult.context_records?.opponent) && (
            <div className="context-insights-panel">
              {calcResult.context_records.venue && (
                <div className="context-box">
                  <h4>🏟️ Venue Benchmark: {calcResult.context_records.venue.name}</h4>
                  <div className="context-stats-row">
                    <span>Avg 1st Innings: <strong>{calcResult.context_records.venue.avg_1st_innings}</strong> runs</span>
                    <span>Bat 1st Win Rate: <strong>{calcResult.context_records.venue.bat_first_win_pct}%</strong></span>
                    <span>Historical Fixtures: <strong>{calcResult.context_records.venue.total_matches}</strong></span>
                  </div>
                </div>
              )}

              {calcResult.context_records.opponent && (
                <div className="context-box">
                  <h4>🛡️ Target Opponent Profile: {calcResult.context_records.opponent.name}</h4>
                  <div className="context-stats-row">
                    <span>Overall Franchise Win Rate: <strong>{calcResult.context_records.opponent.overall_win_pct}%</strong></span>
                    <span>Historical Wins: <strong>{calcResult.context_records.opponent.wins}</strong> / {calcResult.context_records.opponent.matches}</span>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* Exact Historical Matches List (if Method A available) */}
          {calcResult.method_a_exact_xi?.available && calcResult.method_a_exact_xi.summary.matches_list?.length > 0 && (
            <div className="exact-fixtures-block">
              <h4 className="subhead-title">Historical Fixtures Featuring This Exact 11:</h4>
              <div className="fixtures-chips-row">
                {calcResult.method_a_exact_xi.summary.matches_list.map((m) => (
                  <div key={m.id} className={`fixture-chip ${m.won ? 'won' : 'lost'}`}>
                    <span className="chip-result">{m.won ? '✓ WON' : '✕ LOST'}</span>
                    <span className="chip-date">{m.date} ({m.season})</span>
                    <span className="chip-venue">{m.venue}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* If Method A unavailable, show explanation notice */}
          {!calcResult.method_a_exact_xi?.available && (
            <div className="method-notice-box">
              <strong>Notice on Exact Lineup History:</strong> {calcResult.method_a_exact_xi.message} We rely on Method B (distinct team fixtures where selected teammates played together on the same franchise side).
            </div>
          )}

          {/* Individual Contributions & Matchup Table (Part C: Venue & Opponent Records) */}
          <div className="individual-contributions-block">
            <h4 className="subhead-title">Player Records & Contextual Matchup Depth</h4>
            <div className="table-responsive">
              <table className="indiv-contrib-table">
                <thead>
                  <tr>
                    <th>Player</th>
                    <th>Role in XI</th>
                    <th>Career Team Win %</th>
                    <th>Record at Selected Venue</th>
                    <th>Record vs Selected Opponent</th>
                  </tr>
                </thead>
                <tbody>
                  {calcResult.lineup?.players?.map((p) => {
                    const stats = calcResult.individual_contributions?.find((c) => c.player === p.name);
                    const vRec = calcResult.venue_player_stats?.[p.name] || stats?.venue_record;
                    const oRec = calcResult.opponent_player_stats?.[p.name] || stats?.opponent_record;

                    return (
                      <tr key={p.name}>
                        <td><strong>{p.name}</strong></td>
                        <td>
                          <span className={`cand-role-badge role-${p.role?.toLowerCase()?.replace(/\s+/g, '-')}`}>
                            {p.role}
                          </span>
                        </td>
                        <td>
                          <span className="win-pct-tag">
                            {stats?.win_percentage !== undefined ? `${stats.win_percentage}%` : '—'}
                          </span>
                          <span className="sub-sample"> ({stats?.matches || 0}m)</span>
                        </td>
                        <td>
                          {vRec && (vRec.bat_matches > 0 || vRec.bowl_matches > 0 || vRec.matches > 0) ? (
                            <div className="context-record-cell">
                              <span>🏏 {vRec.runs ?? 0}r (SR {vRec.sr ?? vRec.strike_rate ?? 0})</span>
                              <span>🎯 {vRec.wickets ?? 0}w (Econ {vRec.econ ?? vRec.economy ?? 0})</span>
                              <span className="sub-sample">in {Math.max(vRec.bat_matches || 0, vRec.bowl_matches || 0, vRec.matches || 0)}m</span>
                            </div>
                          ) : (
                            <span className="text-muted">No venue record</span>
                          )}
                        </td>
                        <td>
                          {oRec && (oRec.bat_matches > 0 || oRec.bowl_matches > 0 || oRec.matches > 0) ? (
                            <div className="context-record-cell">
                              <span>🏏 {oRec.runs ?? 0}r (SR {oRec.sr ?? oRec.strike_rate ?? 0})</span>
                              <span>🎯 {oRec.wickets ?? 0}w (Econ {oRec.econ ?? oRec.economy ?? 0})</span>
                              <span className="sub-sample">in {Math.max(oRec.bat_matches || 0, oRec.bowl_matches || 0, oRec.matches || 0)}m</span>
                            </div>
                          ) : (
                            <span className="text-muted">No opponent record</span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>

          {/* Transparent Methodology & Statistical Honesty Footer */}
          <div className="methodology-disclosure-footer">
            <h4>📖 Methodology & Statistical Integrity Statement</h4>
            <p>
              <strong>Anti-Fabrication Guarantee:</strong> This application calculates team outcomes strictly through empirical match records. We <em>never sum, multiply, or blindly average</em> individual player percentages, which would produce statistically invalid figures.
            </p>
            <p>
              <strong>Squad Balance Score (0–100):</strong> Evaluated deterministically across 4 structural pillars: Batting Depth (30), Bowling Options (30), All-Rounder Coverage (20), and Aggregate IPL Experience (20).
            </p>
            <p>
              <strong>Historical Association vs Causation:</strong> {calcResult.methodology_statement.association_vs_causation}
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
