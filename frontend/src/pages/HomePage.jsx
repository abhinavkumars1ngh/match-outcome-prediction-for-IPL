// HomePage.jsx — Landing Page for IPL Info
import React from 'react';
import MatchStrip from '../components/MatchStrip';
import './HomePage.css';

export default function HomePage({ setActivePage, totalMatches, onQuickSelect }) {
  const features = [
    {
      id: 'prediction',
      icon: '🔮',
      title: 'Match Outcome Prediction',
      desc: 'Ensemble machine-learning models predicting win probabilities with zero target leakage and full feature explainability.',
      actionText: 'Predict Match →',
    },
    {
      id: 'batter-bowler',
      icon: '⚔️',
      title: 'Batsman vs Bowler Analysis',
      desc: 'Ball-by-ball head-to-head records across 17 IPL seasons. Strike rates, dot balls, dismissals, and boundary contributions.',
      actionText: 'Analyze Matchups →',
    },
    {
      id: 'teams',
      icon: '🛡️',
      title: 'Franchise Performance Archive',
      desc: 'Historical win percentages, titles, defending vs chasing records, and ground performances for all teams.',
      actionText: 'Explore Teams →',
    },
    {
      id: 'players',
      icon: '👤',
      title: 'Player Profiles & Records',
      desc: 'Search over 650+ cricketers. Complete career batting and bowling cards derived from real delivery scorecards.',
      actionText: 'Search Players →',
    },
    {
      id: 'stats',
      icon: '📊',
      title: 'Tournament Leaderboards',
      desc: 'Filter top run-scorers, wicket-takers, and season summaries with comprehensive historical aggregates.',
      actionText: 'View Statistics →',
    },
  ];

  return (
    <div className="home-page">
      {/* Hero Section */}
      <section className="home-hero white-card">
        <div className="hero-badge">
          <span className="badge-dot" />
          <span>Official 17 Seasons IPL Historical Analytics Archive (2008–2024)</span>
        </div>

        <h1 className="hero-title">
          IPL Analytics & <span className="highlight-text">Match Outcome Intelligence</span>
        </h1>

        <p className="hero-desc">
          Explore data-driven cricket analytics powered by 1,095 historical matches, 260,000+ ball-by-ball delivery records, and trained machine-learning prediction models.
        </p>

        <div className="hero-buttons">
          <button className="btn-primary" onClick={() => setActivePage('prediction')}>
            🔮 Predict a Match
          </button>
          <button className="btn-secondary" onClick={() => setActivePage('batter-bowler')}>
            ⚔️ Batsman vs Bowler
          </button>
          <button className="btn-secondary" onClick={() => setActivePage('teams')}>
            🛡️ Explore Teams
          </button>
        </div>

        {/* Aggregate Stats */}
        <div className="hero-stats-row">
          <div className="stat-unit">
            <span className="num">17</span>
            <span className="lbl">Seasons</span>
          </div>
          <div className="stat-sep" />
          <div className="stat-unit">
            <span className="num">{totalMatches ? totalMatches.toLocaleString() : '1,095'}</span>
            <span className="lbl">Matches Recorded</span>
          </div>
          <div className="stat-sep" />
          <div className="stat-unit">
            <span className="num">14</span>
            <span className="lbl">Franchises</span>
          </div>
          <div className="stat-sep" />
          <div className="stat-unit">
            <span className="num">650+</span>
            <span className="lbl">Cricketers</span>
          </div>
          <div className="stat-sep" />
          <div className="stat-unit">
            <span className="num">12</span>
            <span className="lbl">ML Models</span>
          </div>
        </div>
      </section>

      {/* Match Strip Ticker */}
      <MatchStrip onQuickSelect={(t1, t2) => {
        if (onQuickSelect) onQuickSelect(t1, t2);
        setActivePage('prediction');
      }} />

      {/* Quick Navigation Cards */}
      <section className="home-features-section">
        <h2 className="section-heading">Platform Features & Analytics Suites</h2>
        <div className="features-grid">
          {features.map((f) => (
            <div
              key={f.id}
              className="feature-card white-card"
              onClick={() => setActivePage(f.id)}
            >
              <div className="feature-icon">{f.icon}</div>
              <h3>{f.title}</h3>
              <p>{f.desc}</p>
              <span className="feature-link">{f.actionText}</span>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
