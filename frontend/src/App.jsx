// App.jsx — IPL Info Multi-Page Cricket Analytics Engine
import React, { useEffect, useState, useCallback, lazy, Suspense } from 'react';
import { api } from './api';
import Navbar from './components/Navbar';
import MatchStrip from './components/MatchStrip';
import TeamCard from './components/TeamCard';
import ProbabilityBar from './components/ProbabilityBar';
import ModelBreakdown from './components/ModelBreakdown';
import HeadToHead from './components/HeadToHead';
import ExplainabilityPanel from './components/ExplainabilityPanel';
import ModelLeaderboard from './components/ModelLeaderboard';

// Import New Pages
import HomePage from './pages/HomePage';
const TeamsPage = lazy(() => import('./pages/TeamsPage'));
const StatsPage = lazy(() => import('./pages/StatsPage'));
const ProbabilityStatsPage = lazy(() => import('./pages/ProbabilityStatsPage'));
const PlayersPage = lazy(() => import('./pages/PlayersPage'));
const BatterBowlerPage = lazy(() => import('./pages/BatterBowlerPage'));
const My11Page = lazy(() => import('./pages/My11Page'));

import {
  IconTarget,
  IconBrain,
  IconSwords,
  IconBarChart,
} from './components/Icons';

import './App.css';

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

export default function App() {
  // Navigation State: 'home' | 'teams' | 'stats' | 'players' | 'batter-bowler' | 'prediction'
  const [activePage, setActivePage] = useState('home');

  // API State
  const [apiOnline, setApiOnline] = useState(null);
  const [teams, setTeams] = useState([]);
  const [venues, setVenues] = useState([]);
  const [benchmarks, setBenchmarks] = useState([]);
  const [totalMatches, setTotalMatches] = useState(null);
  const [loadingMeta, setLoadingMeta] = useState(true);
  const [metaError, setMetaError] = useState('');

  // Form State
  const [team1, setTeam1] = useState(null);
  const [team2, setTeam2] = useState(null);
  const [venue, setVenue] = useState('');
  const [tossWinner, setTossWinner] = useState('');
  const [tossDecision, setTossDecision] = useState('bat');
  const [isPlayoff, setIsPlayoff] = useState(false);

  // Prediction State
  const [predicting, setPredicting] = useState(false);
  const [prediction, setPrediction] = useState(null);
  const [predError, setPredError] = useState('');

  // H2H State
  const [h2hData, setH2hData] = useState(null);
  const [h2hLoading, setH2hLoading] = useState(false);

  // Load Metadata
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
        setMetaError('Cannot reach the API at http://127.0.0.1:8000. Please ensure the R Plumber server is started.');
      } finally {
        setLoadingMeta(false);
      }
    };
    loadMeta();
  }, []);

  // Auto-load H2H when both teams selected
  useEffect(() => {
    if (!team1 || !team2) { setH2hData(null); return; }
    setH2hLoading(true);
    api.h2h(team1.name, team2.name)
      .then(d => { setH2hData(d); setH2hLoading(false); })
      .catch(() => setH2hLoading(false));
  }, [team1, team2]);

  // Robust Team selection helpers
  const handleTeam1Select = (t) => {
    if (!t) return;
    if (team2?.name === t.name) {
      setTeam2(null);
    }
    setTeam1(t);
    setTossWinner((prev) => (prev === t.name || prev === team2?.name ? prev : t.name));
    setPrediction(null);
    setPredError('');
  };

  const handleTeam2Select = (t) => {
    if (!t) return;
    if (team1?.name === t.name) {
      setTeam1(null);
    }
    setTeam2(t);
    setTossWinner((prev) => (prev === t.name || prev === team1?.name ? prev : t.name));
    setPrediction(null);
    setPredError('');
  };

  const handleQuickSelect = (t1Short, t2Short) => {
    const t1Obj = teams.find(t => t.short_name === t1Short || t.name.includes(t1Short));
    const t2Obj = teams.find(t => t.short_name === t2Short || t.name.includes(t2Short));
    if (t1Obj) setTeam1(t1Obj);
    if (t2Obj) setTeam2(t2Obj);
    if (t1Obj) setTossWinner(t1Obj.name);
    setPrediction(null);
    setPredError('');
  };

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
      setTimeout(() => document.getElementById('result')?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 100);
    } catch (e) {
      setPredError(e.message || 'Prediction failed. Ensure the API is running.');
    } finally {
      setPredicting(false);
    }
  }, [team1, team2, venue, tossWinner, tossDecision, isPlayoff]);

  const t1Color = team1?.primary_color;
  const t2Color = team2?.primary_color;
  const selectedVenueData = venues.find(v => v.venue === venue);
  const formValid = team1 && team2 && venue && tossWinner;

  return (
    <div className="app-layout">
      {/* Editorial Navbar with Logo & IPL Info branding */}
      <Navbar
        activePage={activePage}
        setActivePage={setActivePage}
        apiOnline={apiOnline}
      />

      <main className={`app-wrapper ${activePage === 'home' ? 'app-wrapper--home' : ''}`}>
        <Suspense fallback={<div className="loading-meta" role="status">Loading analytics…</div>}>
        {/* Offline notification if API is disconnected */}
        {apiOnline === false && (
          <div className="error-box" style={{ marginBottom: 20, maxWidth: activePage === 'home' ? '1280px' : undefined, margin: activePage === 'home' ? '16px auto 0' : undefined }}>
            <span>⚠️</span>
            <div>
              <strong>API Disconnected:</strong> {metaError}
            </div>
          </div>
        )}

        {/* ── 1. HOME PAGE ── */}
        {activePage === 'home' && (
          <HomePage
            setActivePage={setActivePage}
            totalMatches={totalMatches}
            onQuickSelect={handleQuickSelect}
            benchmarks={benchmarks}
          />
        )}

        {/* ── 2. TEAMS PAGE ── */}
        {activePage === 'teams' && (
          <TeamsPage
            onSelectForPredict={(t) => {
              setTeam1(t);
              setActivePage('prediction');
            }}
          />
        )}

        {/* ── 3. STATS PAGE ── */}
        {activePage === 'stats' && (
          <StatsPage />
        )}

        {/* ── 3B. PROBABILITY & STATISTICS PAGE ── */}
        {activePage === 'probability-stats' && (
          <ProbabilityStatsPage />
        )}

        {/* ── 4. PLAYERS PAGE ── */}
        {activePage === 'players' && (
          <PlayersPage />
        )}

        {/* ── 5. MY11 PAGE ── */}
        {activePage === 'my11' && (
          <My11Page />
        )}

        {/* ── 6. BATSMAN VS BOWLER PAGE ── */}
        {activePage === 'batter-bowler' && (
          <BatterBowlerPage />
        )}

        {/* ── 6. PREDICTION PAGE ── */}
        {activePage === 'prediction' && (
          <div className="prediction-page-container">
            <div className="page-header">
              <h1 className="page-title">IPL Match Outcome Prediction Engine</h1>
              <p className="page-subtitle">
                Select franchises, ground venue, and toss parameters. Multi-model ensemble calculates zero-target-leakage pre-match win probabilities.
              </p>
            </div>

            <MatchStrip onQuickSelect={handleQuickSelect} />

            <SectionCard
              id="predict"
              icon={<IconTarget size={18} />}
              title="Match Prediction Setup"
              subtitle="Configure team matchup, venue, and toss scenario"
            >
              {loadingMeta ? (
                <div className="loading-meta">
                  <div className="spinner" />
                  <span>Loading franchises and venue records…</span>
                </div>
              ) : (
                <div className="predict-layout">
                  {/* Left: Team 1 */}
                  <div className="team-column">
                    <label className="form-label">
                      <span className="team-col-badge" style={{ background: t1Color || '#15803d' }}>T1</span>
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

                  {/* Center: Configuration Column */}
                  <div className="config-column">
                    <div className="vs-badge">VS</div>

                    {/* Venue */}
                    <div className="config-field">
                      <label className="form-label">Stadium Venue</label>
                      <div className="select-wrapper">
                        <select
                          id="venue-select"
                          className="form-select"
                          value={venue}
                          onChange={e => setVenue(e.target.value)}
                        >
                          <option value="">Select stadium…</option>
                          {venues.map(v => (
                            <option key={v.venue} value={v.venue}>{v.venue} ({v.city})</option>
                          ))}
                        </select>
                      </div>
                      {selectedVenueData && (
                        <div className="venue-stats">
                          <span>Avg 1st Inn: {selectedVenueData.avg_score}</span>
                          <span>Bat 1st win: {selectedVenueData.bat_first_win_pct}%</span>
                        </div>
                      )}
                    </div>

                    {/* Toss Winner */}
                    <div className="config-field">
                      <label className="form-label">Toss Winner</label>
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
                      <label className="form-label">Toss Decision</label>
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
                      <label className="form-label">Tournament Stage</label>
                      <div className="toggle-group">
                        <button
                          className={`toggle-btn ${!isPlayoff ? 'active' : ''}`}
                          onClick={() => setIsPlayoff(false)}
                        >
                          League
                        </button>
                        <button
                          className={`toggle-btn ${isPlayoff ? 'active' : ''}`}
                          onClick={() => setIsPlayoff(true)}
                        >
                          Playoffs
                        </button>
                      </div>
                    </div>

                    {predError && (
                      <div className="error-box">
                        <span>⚠️</span>
                        <span>{predError}</span>
                      </div>
                    )}

                    <button
                      id="predict-btn"
                      className="btn-primary predict-btn"
                      onClick={handlePredict}
                      disabled={predicting || !formValid || apiOnline === false}
                    >
                      {predicting ? (
                        <><div className="spinner" />Computing Models…</>
                      ) : (
                        <><IconTarget size={16} /> Predict Match Outcome</>
                      )}
                    </button>
                  </div>

                  {/* Right: Team 2 */}
                  <div className="team-column">
                    <label className="form-label right-label">
                      Team 2
                      <span className="team-col-badge" style={{ background: t2Color || '#2563eb' }}>T2</span>
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

            {/* Results Grid */}
            {prediction && (
              <div id="result" className="results-grid">
                <SectionCard
                  icon={<IconTarget size={18} />}
                  title="Predicted Match Outcome"
                  subtitle={`Ensemble: ${prediction.result.model_used}`}
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
                      <span className="match-summary-val">{prediction.match.venue}</span>
                    </div>
                    <div className="match-summary-item">
                      <span className="match-summary-label">Toss Factor</span>
                      <span className="match-summary-val">{prediction.match.toss_winner} chose to {prediction.match.toss_decision}</span>
                    </div>
                    <div className="match-summary-item">
                      <span className="match-summary-label">Stage</span>
                      <span className="match-summary-val">{prediction.match.is_playoff ? 'Playoff / Knockout' : 'League Stage'}</span>
                    </div>
                  </div>
                </SectionCard>

                <SectionCard
                  icon={<IconBrain size={18} />}
                  title="Model Consensus Breakdown"
                  subtitle="Individual algorithm estimates for Team 1"
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

            {/* Head-to-Head Section */}
            <SectionCard
              id="h2h"
              icon={<IconSwords size={18} />}
              title="Head-to-Head Encounter History"
              subtitle={team1 && team2 ? `${team1.name} vs ${team2.name}` : 'Select two teams to examine head-to-head records'}
            >
              {!team1 || !team2 ? (
                <div className="placeholder-message">
                  <span className="placeholder-icon"><IconSwords size={32} /></span>
                  <p>Choose two franchises above to view historical encounters and recent 5-match form.</p>
                </div>
              ) : h2hLoading ? (
                <div className="loading-meta"><div className="spinner" /><span>Fetching H2H records…</span></div>
              ) : h2hData ? (
                <HeadToHead
                  data={h2hData}
                  team1={team1.name}
                  team2={team2.name}
                  team1Color={t1Color}
                  team2Color={t2Color}
                />
              ) : (
                <div className="text-muted text-sm">H2H records currently unavailable.</div>
              )}
            </SectionCard>

            {/* Explainability Section */}
            {prediction && (
              <SectionCard
                id="insights"
                icon={<IconBrain size={18} />}
                title="Model Explainability (XAI)"
                subtitle="Dominant statistical drivers behind this forecast"
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

            {/* Model Benchmarks Leaderboard */}
            <SectionCard
              id="models"
              icon={<IconBarChart size={18} />}
              title="Model Benchmark Leaderboard"
              subtitle="Evaluated on held-out test matches — strict zero target leakage"
            >
              <ModelLeaderboard models={benchmarks} />
            </SectionCard>
          </div>
        )}

        {/* Global Footer */}
        <footer className="app-footer">
          <div className="footer-brand">
            <img src="/ipl_info_logo.png" alt="IPL Info" style={{ width: 128, height: 128, borderRadius: 3 }} />
            <span>IPL Info</span>
          </div>
          <p className="footer-text">
            A Comparative Study with multiple Models for Explainable IPL Match Outcome Prediction (2008–2024).
          </p>
          <p className="footer-note">
            Predictions are statistical estimations derived from historical scorecards and 12 benchmarked classification models. Not intended for commercial wagering.
          </p>
        </footer>
        </Suspense>
      </main>
    </div>
  );
}
