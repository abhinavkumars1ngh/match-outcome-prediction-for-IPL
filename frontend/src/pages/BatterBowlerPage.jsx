// BatterBowlerPage.jsx — Batsman vs Bowler Matchup Head-to-Head Analysis
import React, { useState, useEffect } from 'react';
import { api } from '../api';
import './BatterBowlerPage.css';

export default function BatterBowlerPage() {
  const [batsmanQuery, setBatsmanQuery] = useState('');
  const [bowlerQuery, setBowlerQuery] = useState('');

  const [batsmanOptions, setBatsmanOptions] = useState([]);
  const [bowlerOptions, setBowlerOptions] = useState([]);
  const [venues, setVenues] = useState([]);

  const [selectedBatsman, setSelectedBatsman] = useState('V Kohli');
  const [selectedBowler, setSelectedBowler] = useState('B Kumar');
  const [selectedVenue, setSelectedVenue] = useState('');
  const [selectedPhase, setSelectedPhase] = useState('');

  const [matchupData, setMatchupData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Load venues on mount
  useEffect(() => {
    api.venues().then(res => {
      if (res?.venues) setVenues(res.venues);
    }).catch(err => console.error('Venues error:', err));
  }, []);

  // Fetch initial match for V Kohli vs B Kumar
  useEffect(() => {
    analyzeMatchup('V Kohli', 'B Kumar', '', '');
  }, []);

  // Autocomplete for batsman
  useEffect(() => {
    if (batsmanQuery.trim().length > 1) {
      api.players(batsmanQuery, 10).then((res) => {
        if (res?.players) setBatsmanOptions(res.players.map((p) => p.player_name));
      });
    } else {
      setBatsmanOptions([]);
    }
  }, [batsmanQuery]);

  // Autocomplete for bowler
  useEffect(() => {
    if (bowlerQuery.trim().length > 1) {
      api.players(bowlerQuery, 10).then((res) => {
        if (res?.players) setBowlerOptions(res.players.map((p) => p.player_name));
      });
    } else {
      setBowlerOptions([]);
    }
  }, [bowlerQuery]);

  const analyzeMatchup = (bat, bwl, ven, ph) => {
    if (!bat || !bwl) return;
    setLoading(true);
    setError('');
    api.batterBowler(bat, bwl, ven, ph)
      .then((res) => setMatchupData(res))
      .catch((err) => setError(err.message || 'Failed to analyze matchup.'))
      .finally(() => setLoading(false));
  };

  const handleRunAnalysis = () => {
    if (!selectedBatsman || !selectedBowler) {
      setError('Please select both a batsman and a bowler.');
      return;
    }
    analyzeMatchup(selectedBatsman, selectedBowler, selectedVenue, selectedPhase);
  };

  const handlePhaseChange = (phaseKey) => {
    setSelectedPhase(phaseKey);
    analyzeMatchup(selectedBatsman, selectedBowler, selectedVenue, phaseKey);
  };

  const handleVenueChange = (ven) => {
    setSelectedVenue(ven);
    analyzeMatchup(selectedBatsman, selectedBowler, ven, selectedPhase);
  };

  const phases = [
    { key: '', label: 'All Overs (0–20)' },
    { key: 'powerplay', label: 'Powerplay (0–5)' },
    { key: 'middle', label: 'Middle (6–14)' },
    { key: 'death', label: 'Death (15–19)' }
  ];

  return (
    <div className="batter-bowler-page">
      <div className="page-header">
        <div className="header-badge-row">
          <span className="section-pill">HEAD-TO-HEAD MATCHUP ENGINE</span>
          <span className="section-pill-gold">PHASE & VENUE SEGMENTATION</span>
        </div>
        <h1 className="page-title">Batsman vs Bowler — Head-to-Head Breakdown</h1>
        <p className="page-subtitle">
          Ball-by-ball historical analysis derived from real delivery records (2008–2024). Compare phase execution, baseline strike rate deviations, and tactical insights without synthetic approximations.
        </p>
      </div>

      {/* Selection Card */}
      <div className="white-card selection-card">
        <div className="selectors-row">
          {/* Batsman Selector */}
          <div className="player-selector-box">
            <label className="form-label">Select Batsman (Batter)</label>
            <div className="chosen-pill">
              <span>🏏 {selectedBatsman || 'None chosen'}</span>
            </div>
            <div className="autocomplete-wrap">
              <input
                type="text"
                className="form-input"
                placeholder="Type name (e.g. V Kohli, RG Sharma, DA Warner)..."
                value={batsmanQuery}
                onChange={(e) => setBatsmanQuery(e.target.value)}
              />
              {batsmanOptions.length > 0 && (
                <div className="options-dropdown">
                  {batsmanOptions.map((name) => (
                    <div
                      key={name}
                      className="option-item"
                      onClick={() => {
                        setSelectedBatsman(name);
                        setBatsmanQuery('');
                        setBatsmanOptions([]);
                      }}
                    >
                      {name}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          <div className="vs-divider">VS</div>

          {/* Bowler Selector */}
          <div className="player-selector-box">
            <label className="form-label">Select Bowler</label>
            <div className="chosen-pill">
              <span>🎯 {selectedBowler || 'None chosen'}</span>
            </div>
            <div className="autocomplete-wrap">
              <input
                type="text"
                className="form-input"
                placeholder="Type name (e.g. B Kumar, JJ Bumrah, YS Chahal)..."
                value={bowlerQuery}
                onChange={(e) => setBowlerQuery(e.target.value)}
              />
              {bowlerOptions.length > 0 && (
                <div className="options-dropdown">
                  {bowlerOptions.map((name) => (
                    <div
                      key={name}
                      className="option-item"
                      onClick={() => {
                        setSelectedBowler(name);
                        setBowlerQuery('');
                        setBowlerOptions([]);
                      }}
                    >
                      {name}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Filters row: Venue & Phase */}
        <div className="matchup-context-row">
          <div className="context-item">
            <label className="form-label">🏟️ Venue Filter (Optional)</label>
            <select
              className="form-input"
              value={selectedVenue}
              onChange={(e) => handleVenueChange(e.target.value)}
            >
              <option value="">All Stadiums Combined</option>
              {venues.map((v) => (
                <option key={v.venue} value={v.venue}>{v.venue} ({v.city})</option>
              ))}
            </select>
          </div>

          <div className="context-item">
            <label className="form-label">⏱️ Match Phase Filter</label>
            <div className="phase-pill-group">
              {phases.map((ph) => (
                <button
                  key={ph.key}
                  className={`phase-btn ${selectedPhase === ph.key ? 'active' : ''}`}
                  onClick={() => handlePhaseChange(ph.key)}
                >
                  {ph.label}
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="analyze-action">
          <button className="btn-primary" onClick={handleRunAnalysis} disabled={loading}>
            {loading ? 'Analyzing Deliveries…' : 'Update Matchup Stats'}
          </button>
        </div>
      </div>

      {error && (
        <div className="error-box">
          <span>⚠️</span>
          <span>{error}</span>
        </div>
      )}

      {/* Matchup Results */}
      {matchupData && (
        <div className="matchup-results-wrap">
          {/* Matchup Banner */}
          <div className="matchup-banner white-card">
            <div className="player-side">
              <div className="player-badge-initials">{matchupData.matchup.batsman.substring(0, 2).toUpperCase()}</div>
              <div>
                <h3>{matchupData.matchup.batsman}</h3>
                <span className="role-tag">Batter (Career SR: {matchupData.baselines?.batsman_career_strike_rate || '—'})</span>
              </div>
            </div>

            <div className="matchup-score-center">
              <div className="headline-stats">
                <span className="h-runs">{matchupData.stats.runs} Runs</span>
                <span className="h-sep">off</span>
                <span className="h-balls">{matchupData.stats.balls} Balls</span>
              </div>
              <div className="h-dismissals">
                {matchupData.stats.dismissals} Dismissals across {matchupData.stats.matches} Matches
              </div>
              {selectedVenue && (
                <div className="filter-active-tag">🏟️ Filtered by: {selectedVenue}</div>
              )}
              {selectedPhase && (
                <div className="filter-active-tag">⏱️ Phase: {selectedPhase.toUpperCase()}</div>
              )}
            </div>

            <div className="player-side right">
              <div>
                <h3>{matchupData.matchup.bowler}</h3>
                <span className="role-tag">Bowler (Career Econ: {matchupData.baselines?.bowler_career_economy || '—'})</span>
              </div>
              <div className="player-badge-initials bowler">{matchupData.matchup.bowler.substring(0, 2).toUpperCase()}</div>
            </div>
          </div>

          {/* Metric Cards Grid */}
          <div className="metrics-grid">
            <div className="metric-card white-card">
              <div className="m-val">{matchupData.stats.strike_rate}</div>
              <div className="m-lbl">Matchup Strike Rate</div>
              <div className="m-desc">
                Career baseline: <strong>{matchupData.baselines?.batsman_career_strike_rate}</strong> (Diff: {matchupData.baselines?.strike_rate_diff > 0 ? '+' : ''}{matchupData.baselines?.strike_rate_diff})
              </div>
            </div>
            <div className="metric-card white-card">
              <div className="m-val">{matchupData.stats.average}</div>
              <div className="m-lbl">Matchup Batting Average</div>
              <div className="m-desc">{matchupData.stats.runs} runs / {matchupData.stats.dismissals} outs</div>
            </div>
            <div className="metric-card white-card">
              <div className="m-val">{matchupData.stats.dot_pct}%</div>
              <div className="m-lbl">Dot Ball Percentage</div>
              <div className="m-desc">{matchupData.stats.dots} scoreless deliveries ({matchupData.stats.balls} total)</div>
            </div>
            <div className="metric-card white-card">
              <div className="m-val">{matchupData.stats.boundary_pct}%</div>
              <div className="m-lbl">Boundary Run Contribution</div>
              <div className="m-desc">{matchupData.stats.fours} Fours · {matchupData.stats.sixes} Sixes</div>
            </div>
          </div>

          {/* Tactical Insights & Baseline Comparison Card */}
          {matchupData.insights && (
            <div className="white-card tactical-insights-card">
              <div className="tactical-header">
                <span className="tactical-icon">💡</span>
                <h4>Evidence-Based Tactical Insight</h4>
              </div>
              <p className="tactical-text">{matchupData.insights.summary}</p>
              <div className="tactical-tags">
                <span className={`verdict-pill ${matchupData.insights.favour}`}>
                  Tactical Edge: {matchupData.insights.favour.toUpperCase()}
                </span>
                <span className="baseline-comp-pill">
                  Sample Confidence: {matchupData.stats.balls >= 30 ? 'High (30+ Balls)' : matchupData.stats.balls >= 15 ? 'Moderate' : 'Limited Sample'}
                </span>
              </div>
            </div>
          )}

          {/* Match Phase Breakdown Table */}
          {matchupData.phase_breakdown && matchupData.phase_breakdown.length > 0 && (
            <div className="white-card phase-table-card">
              <h4>Phase-by-Phase Head-to-Head Performance</h4>
              <div className="table-responsive">
                <table className="phase-table">
                  <thead>
                    <tr>
                      <th>Match Phase</th>
                      <th>Overs</th>
                      <th>Balls</th>
                      <th>Runs</th>
                      <th>Dismissals</th>
                      <th>Strike Rate</th>
                      <th>Dots %</th>
                      <th>4s / 6s</th>
                    </tr>
                  </thead>
                  <tbody>
                    {matchupData.phase_breakdown.map((row) => (
                      <tr key={row.phase_key} className={selectedPhase === row.phase_key ? 'active-row' : ''}>
                        <td className="phase-cell-name">
                          <strong>{row.phase}</strong>
                        </td>
                        <td>{row.overs}</td>
                        <td>{row.balls}</td>
                        <td>{row.runs}</td>
                        <td>
                          <span className={row.dismissals > 0 ? 'badge-out' : ''}>
                            {row.dismissals}
                          </span>
                        </td>
                        <td>
                          <strong>{row.strike_rate}</strong>
                        </td>
                        <td>{row.dot_pct}%</td>
                        <td>{row.fours} / {row.sixes}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* Ball Length & Shot Selection Honesty Panel */}
          <div className="white-card technical-limitations-card">
            <h4>Delivery Length & Shot-Type Analysis</h4>
            <p className="note-text">
              {matchupData.note}
            </p>
            <div className="limitations-badge">
              <span>ℹ️ Strictly zero synthetic fabrication — metrics only derived from verified scorecard deliveries.</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
