// App.jsx — IPL Oracle main application
import React, { useEffect, useState, useCallback } from 'react';
import { api } from './api';
import Navbar from './components/Navbar';
import Hero from './components/Hero';
import TeamCard from './components/TeamCard';
import ProbabilityBar from './components/ProbabilityBar';
import ModelBreakdown from './components/ModelBreakdown';
import HeadToHead from './components/HeadToHead';
import ExplainabilityPanel from './components/ExplainabilityPanel';
import ModelLeaderboard from './components/ModelLeaderboard';
import './App.css';

// ── Helpers ───────────────────────────────────────────────────────────────────
function SectionCard({ id, icon, title, subtitle, iconBg, children, className = '' }) {
  return (
    <section id={id} className={`glass-card section-card ${className}`}>
      <div className="section-header">
        <div className="section-icon" style={{ background: iconBg }}>
          {icon}
        </div>
        <div>
          <div className="section-title">{title}</div>
          {subtitle && <div className="section-subtitle">{subtitle}</div>}
        </div>
      </div>
      {children}
    </section>
  );
}

// ── Main App ──────────────────────────────────────────────────────────────────
export default function App() {
  // ── API State ────────────────────────────────────────────────────────────
  const [apiOnline, setApiOnline] = useState(null);
  const [teams, setTeams] = useState([]);
  const [venues, setVenues] = useState([]);
  const [benchmarks, setBenchmarks] = useState([]);
  const [totalMatches, setTotalMatches] = useState(null);
  const [loadingMeta, setLoadingMeta] = useState(true);
  const [metaError, setMetaError] = useState('');

  // ── Form State ───────────────────────────────────────────────────────────
  const [team1, setTeam1] = useState(null);
  const [team2, setTeam2] = useState(null);
  const [venue, setVenue] = useState('');
  const [tossWinner, setTossWinner] = useState('');
  const [tossDecision, setTossDecision] = useState('bat');
  const [isPlayoff, setIsPlayoff] = useState(false);

  // ── Prediction State ─────────────────────────────────────────────────────
  const [predicting, setPredicting] = useState(false);
  const [prediction, setPrediction] = useState(null);
  const [predError, setPredError] = useState('');

  // ── H2H State ────────────────────────────────────────────────────────────
  const [h2hData, setH2hData] = useState(null);
  const [h2hLoading, setH2hLoading] = useState(false);

  // ── Init: Load metadata ───────────────────────────────────────────────────
  useEffect(() => {
    const loadMeta = async () => {
      try {
        const [healthRes, teamsRes, venuesRes, modelsRes] = await Promise.all([
          api.health(),
          api.teams(),
          api.venues(),
          api.models(),
        ]);
        setApiOnline(true);
        setTotalMatches(healthRes?.database?.total_matches);
        if (teamsRes?.teams) setTeams(teamsRes.teams);
        if (venuesRes?.venues) setVenues(venuesRes.venues);
        if (modelsRes?.benchmark) setBenchmarks(Array.isArray(modelsRes.benchmark) ? modelsRes.benchmark : []);
      } catch (e) {
        setApiOnline(false);
        setMetaError('Cannot reach the API at http://127.0.0.1:8000. Please start the R Plumber server.');
      } finally {
        setLoadingMeta(false);
      }
    };
    loadMeta();
  }, []);

  // ── Auto-load H2H when both teams selected ────────────────────────────────
  useEffect(() => {
    if (!team1 || !team2) { setH2hData(null); return; }
    setH2hLoading(true);
    api.h2h(team1.name, team2.name)
      .then(d => { setH2hData(d); setH2hLoading(false); })
      .catch(() => setH2hLoading(false));
  }, [team1, team2]);

  // ── Team selection helpers ────────────────────────────────────────────────
  const handleTeam1Select = (t) => {
    if (team2?.name === t.name) return; // can't pick same
    setTeam1(t);
    setTossWinner('');
    setPrediction(null);
    setPredError('');
  };
  const handleTeam2Select = (t) => {
    if (team1?.name === t.name) return;
    setTeam2(t);
    setTossWinner('');
    setPrediction(null);
    setPredError('');
  };

  // ── Predict ───────────────────────────────────────────────────────────────
  const handlePredict = useCallback(async () => {
    setPredError('');
    if (!team1) return setPredError('Please select Team 1.');
    if (!team2) return setPredError('Please select Team 2.');
    if (!venue) return setPredError('Please select a venue.');
    if (!tossWinner) return setPredError('Please select the toss winner.');

    setPredicting(true);
    setPrediction(null);
    try {
      const res = await api.predict({
        team1: team1.name,
        team2: team2.name,
        venue,
        toss_winner: tossWinner,
        toss_decision: tossDecision,
        is_playoff: isPlayoff ? 1 : 0,
        model: 'Consensus',
      });
      setPrediction(res);
      // Scroll to result
      setTimeout(() => document.getElementById('result')?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 100);
    } catch (e) {
      setPredError(e.message || 'Prediction failed. Ensure the API is running.');
    } finally {
      setPredicting(false);
    }
  }, [team1, team2, venue, tossWinner, tossDecision, isPlayoff]);

  // ── Derived values ────────────────────────────────────────────────────────
  const t1Color = team1?.primary_color;
  const t2Color = team2?.primary_color;
  const selectedVenueData = venues.find(v => v.venue === venue);

  const formValid = team1 && team2 && venue && tossWinner;

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <>
      <div className="app-bg" aria-hidden="true" />
      <div className="app-layout">
        <Navbar apiOnline={apiOnline} />

        <main className="app-wrapper">
          {/* Hero */}
          <Hero totalMatches={totalMatches} />

          {/* API Offline Banner */}
          {apiOnline === false && (
            <div className="error-box anim-fade-up" style={{ marginBottom: 24 }}>
              <span>⚠️</span>
              <div>
                <strong>API Offline:</strong> {metaError}
                <br />
                <code style={{ fontSize: '0.8em', opacity: 0.8 }}>Rscript api/start_server.R</code>
              </div>
            </div>
          )}

          {/* ── PREDICTION SETUP ─────────────────────────────────────────── */}
          <SectionCard
            id="predict"
            icon="🔮"
            title="Match Prediction Setup"
            subtitle="Select teams, venue and match conditions"
            iconBg="linear-gradient(135deg, #7c3aed, #3b82f6)"
            className="anim-fade-up delay-1"
          >
            {loadingMeta ? (
              <div className="loading-meta">
                <div className="spinner" />
                <span>Loading teams and venues…</span>
              </div>
            ) : (
              <div className="predict-layout">
                {/* Left: Team 1 */}
                <div className="team-column">
                  <label className="form-label">
                    <span className="team-col-badge" style={{ background: t1Color || '#7c3aed' }}>T1</span>
                    Team 1
                  </label>
                  <div className="team-list">
                    {teams.map(t => (
                      <TeamCard
                        key={t.name}
                        team={t}
                        selected={team1?.name === t.name}
                        onSelect={handleTeam1Select}
                        side="left"
                      />
                    ))}
                  </div>
                </div>

                {/* Center: VS + config */}
                <div className="config-column">
                  <div className="vs-badge">VS</div>

                  {/* Venue */}
                  <div className="config-field">
                    <label className="form-label">🏟️ Venue</label>
                    <div className="select-wrapper">
                      <select
                        id="venue-select"
                        className="form-select"
                        value={venue}
                        onChange={e => setVenue(e.target.value)}
                      >
                        <option value="">Select venue…</option>
                        {venues.map(v => (
                          <option key={v.venue} value={v.venue}>{v.venue} ({v.city})</option>
                        ))}
                      </select>
                    </div>
                    {selectedVenueData && (
                      <div className="venue-stats">
                        <span>Avg score: {selectedVenueData.avg_score}</span>
                        <span>Bat first wins: {selectedVenueData.bat_first_win_pct}%</span>
                      </div>
                    )}
                  </div>

                  {/* Toss Winner */}
                  <div className="config-field">
                    <label className="form-label">🪙 Toss Winner</label>
                    <div className="toggle-group">
                      <button
                        className={`toggle-btn ${tossWinner === (team1?.name || '') ? 'active' : ''}`}
                        onClick={() => team1 && setTossWinner(team1.name)}
                        disabled={!team1}
                      >
                        {team1 ? team1.short_name : 'Team 1'}
                      </button>
                      <button
                        className={`toggle-btn ${tossWinner === (team2?.name || '') ? 'active' : ''}`}
                        onClick={() => team2 && setTossWinner(team2.name)}
                        disabled={!team2}
                      >
                        {team2 ? team2.short_name : 'Team 2'}
                      </button>
                    </div>
                  </div>

                  {/* Toss Decision */}
                  <div className="config-field">
                    <label className="form-label">🏏 Toss Decision</label>
                    <div className="toggle-group">
                      <button
                        className={`toggle-btn ${tossDecision === 'bat' ? 'active' : ''}`}
                        onClick={() => setTossDecision('bat')}
                      >
                        Bat First
                      </button>
                      <button
                        className={`toggle-btn ${tossDecision === 'field' ? 'active' : ''}`}
                        onClick={() => setTossDecision('field')}
                      >
                        Field First
                      </button>
                    </div>
                  </div>

                  {/* Match Stage */}
                  <div className="config-field">
                    <label className="form-label">🏆 Match Stage</label>
                    <div className="toggle-group">
                      <button
                        className={`toggle-btn ${!isPlayoff ? 'active' : ''}`}
                        onClick={() => setIsPlayoff(false)}
                      >
                        League Stage
                      </button>
                      <button
                        className={`toggle-btn ${isPlayoff ? 'active' : ''}`}
                        onClick={() => setIsPlayoff(true)}
                      >
                        Playoff
                      </button>
                    </div>
                  </div>

                  {/* Error */}
                  {predError && (
                    <div className="error-box">
                      <span>⚠️</span>
                      <span>{predError}</span>
                    </div>
                  )}

                  {/* Predict Button */}
                  <button
                    id="predict-btn"
                    className="btn-primary predict-btn"
                    onClick={handlePredict}
                    disabled={predicting || !formValid || apiOnline === false}
                  >
                    {predicting ? (
                      <><div className="spinner" />Running Models…</>
                    ) : (
                      <><span>🔮</span> Predict Match Outcome</>
                    )}
                  </button>
                </div>

                {/* Right: Team 2 */}
                <div className="team-column">
                  <label className="form-label right-label">
                    Team 2
                    <span className="team-col-badge" style={{ background: t2Color || '#3b82f6' }}>T2</span>
                  </label>
                  <div className="team-list">
                    {teams.map(t => (
                      <TeamCard
                        key={t.name}
                        team={t}
                        selected={team2?.name === t.name}
                        onSelect={handleTeam2Select}
                        side="right"
                      />
                    ))}
                  </div>
                </div>
              </div>
            )}
          </SectionCard>

          {/* ── PREDICTION RESULT ──────────────────────────────────────────── */}
          {prediction && (
            <div id="result" className="results-grid anim-scale">
              {/* Win Probability */}
              <SectionCard
                icon="🎯"
                title="Predicted Outcome"
                subtitle={`Model: ${prediction.result.model_used}`}
                iconBg="linear-gradient(135deg, #f97316, #fbbf24)"
                className="result-primary"
              >
                <ProbabilityBar
                  team1={prediction.match.team1}
                  team2={prediction.match.team2}
                  team1Prob={prediction.result.team1_win_percentage}
                  team2Prob={prediction.result.team2_win_percentage}
                  predictedWinner={prediction.result.predicted_winner}
                  team1Color={t1Color}
                  team2Color={t2Color}
                />

                <div className="divider" />

                <div className="match-summary">
                  <div className="match-summary-item">
                    <span className="match-summary-label">Venue</span>
                    <span className="match-summary-val">🏟️ {prediction.match.venue}</span>
                  </div>
                  <div className="match-summary-item">
                    <span className="match-summary-label">Toss</span>
                    <span className="match-summary-val">🪙 {prediction.match.toss_winner} chose to {prediction.match.toss_decision}</span>
                  </div>
                  <div className="match-summary-item">
                    <span className="match-summary-label">Stage</span>
                    <span className="match-summary-val">{prediction.match.is_playoff ? '🏆 Playoff' : '📅 League'}</span>
                  </div>
                </div>
              </SectionCard>

              {/* Model Breakdown */}
              <SectionCard
                icon="🤖"
                title="All-Model Breakdown"
                subtitle="Individual model probabilities for Team 1"
                iconBg="linear-gradient(135deg, #7c3aed, #a855f7)"
              >
                <ModelBreakdown
                  breakdown={prediction.all_models_breakdown}
                  consensus={prediction.consensus_probability}
                  team1={prediction.match.team1}
                  team2={prediction.match.team2}
                  benchmarks={benchmarks}
                />
              </SectionCard>
            </div>
          )}

          {/* ── HEAD-TO-HEAD ─────────────────────────────────────────────── */}
          <SectionCard
            id="h2h"
            icon="⚔️"
            title="Head-to-Head Analysis"
            subtitle={team1 && team2 ? `${team1.name} vs ${team2.name}` : 'Select both teams above'}
            iconBg="linear-gradient(135deg, #ef4444, #f97316)"
            className="anim-fade-up delay-2"
          >
            {!team1 || !team2 ? (
              <div className="placeholder-message">
                <span className="placeholder-icon">⚔️</span>
                <p>Select two teams above to view their head-to-head record and recent form.</p>
              </div>
            ) : h2hLoading ? (
              <div className="loading-meta"><div className="spinner" /><span>Loading H2H data…</span></div>
            ) : h2hData ? (
              <HeadToHead
                data={h2hData}
                team1={team1.name}
                team2={team2.name}
                team1Color={t1Color}
                team2Color={t2Color}
              />
            ) : (
              <div className="text-muted text-sm">H2H data unavailable.</div>
            )}
          </SectionCard>

          {/* ── EXPLAINABILITY ────────────────────────────────────────────── */}
          {prediction && (
            <SectionCard
              id="insights"
              icon="🧠"
              title="Prediction Explainability"
              subtitle="Why the model chose this outcome"
              iconBg="linear-gradient(135deg, #0ea5e9, #00d4ff)"
              className="anim-fade-up"
            >
              <ExplainabilityPanel
                xai={prediction.explainability}
                team1={prediction.match.team1}
                team2={prediction.match.team2}
                features={prediction.computed_features}
                team1Color={t1Color}
                team2Color={t2Color}
              />
            </SectionCard>
          )}

          {/* ── MODEL LEADERBOARD ─────────────────────────────────────────── */}
          <SectionCard
            id="models"
            icon="📊"
            title="Model Benchmark Leaderboard"
            subtitle="Evaluated on held-out test set — zero target leakage"
            iconBg="linear-gradient(135deg, #22c55e, #0ea5e9)"
            className="anim-fade-up delay-3"
          >
            <ModelLeaderboard models={benchmarks} />
          </SectionCard>

          {/* ── FOOTER ───────────────────────────────────────────────────── */}
          <footer className="app-footer">
            <div className="footer-brand">
              <span>🏏</span>
              <span className="gradient-text">IPL Oracle</span>
            </div>
            <p className="footer-text">
              Ensemble machine-learning prediction engine · 17 seasons of IPL data (2008–2024)
              · Built as a college ML project
            </p>
            <p className="footer-note">
              Predictions are probabilistic estimates based on historical data. Not for betting use.
            </p>
          </footer>
        </main>
      </div>
    </>
  );
}
