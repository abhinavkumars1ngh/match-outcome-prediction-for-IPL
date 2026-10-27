// HomePage.jsx — World-Class 3D Cinematic Cricket Analytics Experience
import React, { useState, useEffect, useRef } from 'react';
import CinematicHero from '../components/CinematicHero';
import MatchStrip from '../components/MatchStrip';
import {
  IconTarget,
  IconSwords,
  IconShield,
  IconUser,
  IconBarChart,
  IconTrendingUp,
  IconBrain,
  IconDatabase,
  IconCheckCircle,
  IconArrowRight,
  IconSliders,
  IconLayers,
  IconSparkles,
} from '../components/Icons';
import './HomePage.css';

// Verified empirical benchmarks from out-of-sample evaluation (results/model_comparison.csv)
const VERIFIED_BENCHMARKS = [
  { Model: 'Decision Tree', Accuracy: 0.5321, Precision: 0.5455, Recall: 0.5357, F1: 0.5405, ROC_AUC: 0.5399, Rank: 1 },
  { Model: 'KNN', Accuracy: 0.5275, Precision: 0.5616, Recall: 0.3661, F1: 0.4432, ROC_AUC: 0.5218, Rank: 2 },
  { Model: 'Gradient Boosting', Accuracy: 0.5138, Precision: 0.5455, Recall: 0.3214, F1: 0.4045, ROC_AUC: 0.5150, Rank: 3 },
  { Model: 'AdaBoost', Accuracy: 0.5092, Precision: 0.5424, Recall: 0.2857, F1: 0.3743, ROC_AUC: 0.5194, Rank: 4 },
  { Model: 'SVM', Accuracy: 0.4954, Precision: 0.5152, Recall: 0.3036, F1: 0.3820, ROC_AUC: 0.5248, Rank: 5 },
  { Model: 'Naive Bayes', Accuracy: 0.4908, Precision: 0.5057, Recall: 0.3929, F1: 0.4422, ROC_AUC: 0.4959, Rank: 6 },
  { Model: 'Logistic Regression', Accuracy: 0.4862, Precision: 0.5000, Recall: 0.3482, F1: 0.4105, ROC_AUC: 0.5216, Rank: 7 },
  { Model: 'MLP (Neural Net)', Accuracy: 0.4817, Precision: 0.4938, Recall: 0.3571, F1: 0.4145, ROC_AUC: 0.5164, Rank: 8 },
  { Model: 'Bagging', Accuracy: 0.4725, Precision: 0.4839, Recall: 0.4018, F1: 0.4390, ROC_AUC: 0.5366, Rank: 9 },
  { Model: 'SGD Classifier', Accuracy: 0.4725, Precision: 0.4842, Recall: 0.4107, F1: 0.4444, ROC_AUC: 0.4993, Rank: 10 },
  { Model: 'Extra Trees', Accuracy: 0.4725, Precision: 0.4717, Recall: 0.2232, F1: 0.3030, ROC_AUC: 0.5334, Rank: 11 },
  { Model: 'Random Forest', Accuracy: 0.4128, Precision: 0.3919, Recall: 0.2589, F1: 0.3118, ROC_AUC: 0.5951, Rank: 12 },
];

// Smooth Animated Counter Hook
function AnimatedNumber({ value, duration = 1400, suffix = '' }) {
  const [displayValue, setDisplayValue] = useState(0);
  const elementRef = useRef(null);
  useEffect(() => {
    const target = Number(value) || 0;
    let frame = 0;
    const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
    const finish = () => { cancelAnimationFrame(frame); setDisplayValue(target); };
    const observer = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting) return;
      observer.disconnect();
      if (motion.matches) { finish(); return; }
      let start;
      const step = (time) => {
        start ??= time;
        const progress = Math.min((time - start) / duration, 1);
        setDisplayValue(Math.round(target * (1 - Math.pow(1 - progress, 3))));
        if (progress < 1) frame = requestAnimationFrame(step);
      };
      frame = requestAnimationFrame(step);
    }, { threshold: 0.2 });
    observer.observe(elementRef.current);
    motion.addEventListener('change', finish);
    return () => { observer.disconnect(); cancelAnimationFrame(frame); motion.removeEventListener('change', finish); };
  }, [value, duration]);
  return <span ref={elementRef}>{displayValue.toLocaleString()}{suffix}</span>;
}

export default function HomePage({ setActivePage, totalMatches, onQuickSelect, benchmarks = [] }) {
  const [activeModelTab, setActiveModelTab] = useState('all');

  // Use live benchmarks if provided, fallback to verified results
  const displayModels =
    benchmarks && benchmarks.length > 0
      ? [...benchmarks]
          .sort((a, b) => Number(b.Accuracy || 0) - Number(a.Accuracy || 0))
          .map((m, i) => ({
            ...m,
            Rank: i + 1,
            ROC_AUC: m.ROC_AUC || m['AUC-ROC'] || m.AUC || 0,
          }))
      : VERIFIED_BENCHMARKS;

  const topModels = displayModels.slice(0, 6);
  const modelsToShow = activeModelTab === 'top6' ? topModels : displayModels;

  const features = [
    {
      id: 'prediction',
      icon: <IconTarget size={22} />,
      title: 'Match Outcome Prediction Engine',
      desc: 'Ensemble model consensus predicting win probabilities with zero target leakage, real-time feature derivation, and explainable statistical drivers.',
      actionText: 'Predict Match Outcome',
      badge: 'Core Engine',
    },
    {
      id: 'probability-stats',
      icon: <IconTrendingUp size={22} />,
      title: 'Empirical Probability & Distributions',
      desc: 'First-innings score variance, 95% Wilson confidence intervals, defending vs chasing biases, and franchise-by-venue cross-tabulation matrices.',
      actionText: 'Explore Probability Space',
      badge: 'Empirical Bayes',
    },
    {
      id: 'batter-bowler',
      icon: <IconSwords size={22} />,
      title: 'Batsman vs Bowler Matchups (H2H)',
      desc: 'Granular ball-by-ball head-to-head records across 17 IPL seasons. Strike rates, dot balls, dismissals, and match-phase splits.',
      actionText: 'Analyze Head-to-Head',
      badge: 'Ball-by-Ball',
    },
    {
      id: 'teams',
      icon: <IconShield size={22} />,
      title: 'Franchise Performance Archive',
      desc: 'Historical win percentages, championship records, defending vs chasing splits, and venue-specific win rates across all 14 franchises.',
      actionText: 'Explore Franchises',
      badge: '14 Teams',
    },
    {
      id: 'players',
      icon: <IconUser size={22} />,
      title: 'Player Profiles & Scorecards',
      desc: 'Complete career batting and bowling performance cards for over 650+ cricketers derived directly from official delivery records.',
      actionText: 'Search 650+ Players',
      badge: 'Career Cards',
    },
    {
      id: 'stats',
      icon: <IconBarChart size={22} />,
      title: 'Tournament Leaderboards',
      desc: 'Comprehensive historical aggregates for top run-scorers, wicket-takers, boundary percentages, and season-by-season summaries.',
      actionText: 'View Leaderboards',
      badge: 'All-Time Records',
    },
  ];

  const researchPillars = [
    {
      icon: <IconLayers size={22} />,
      title: 'Comparative Model Evaluation',
      desc: '12 distinct classification architectures benchmarked under identical out-of-sample test conditions (2022–2024 holdout seasons).',
    },
    {
      icon: <IconSliders size={22} />,
      title: 'Zero Target Leakage Feature Engineering',
      desc: '15 pre-match features calculated strictly via chronological rolling windows, preventing lookahead bias in model evaluation.',
    },
    {
      icon: <IconBrain size={22} />,
      title: 'Explainable AI & Feature Attribution',
      desc: 'Permutation importance drops and Gini importance metrics reveal key drivers including venue averages and historical win differences.',
    },
    {
      icon: <IconDatabase size={22} />,
      title: 'Relational SQLite Architecture',
      desc: 'High-performance SQL schema storing 1,095 matches and 260,920 delivery records for deterministic, reproducible queries.',
    },
  ];

  return (
    <div className="home-page-root">
      {/* ── 1. CINEMATIC 3D VIDEO HERO SECTION ────────────────────── */}
      <CinematicHero setActivePage={setActivePage} benchmarks={displayModels} />

      {/* ── 2. STATS OVERVIEW PANEL (ANIMATED COUNTERS) ──────────── */}
      <div id="home-stats-overview" className="stats-overview-section">
        <div className="stats-overview-container">
          <div className="stat-overview-card">
            <div className="stat-card-top">
              <span className="stat-card-num">
                <AnimatedNumber value={12} duration={1000} />
              </span>
              <span className="stat-pill-tag">Benchmarked</span>
            </div>
            <div className="stat-card-label">ML Algorithms</div>
            <div className="stat-card-sub">Classifiers Evaluated</div>
          </div>

          <div className="stat-overview-card">
            <div className="stat-card-top">
              <span className="stat-card-num">
                <AnimatedNumber value={totalMatches || 1095} duration={1400} />
              </span>
              <span className="stat-pill-tag">2008–2024</span>
            </div>
            <div className="stat-card-label">Matches Analyzed</div>
            <div className="stat-card-sub">17 Full IPL Seasons</div>
          </div>

          <div className="stat-overview-card">
            <div className="stat-card-top">
              <span className="stat-card-num">
                <AnimatedNumber value={15} duration={1100} />
              </span>
              <span className="stat-pill-tag">Zero Leakage</span>
            </div>
            <div className="stat-card-label">Pre-Match Features</div>
            <div className="stat-card-sub">Rolling Historical Windows</div>
          </div>

          <div className="stat-overview-card">
            <div className="stat-card-top">
              <span className="stat-card-num">
                <AnimatedNumber value={260} duration={1300} suffix="K+" />
              </span>
              <span className="stat-pill-tag">Ball-by-Ball</span>
            </div>
            <div className="stat-card-label">Deliveries Tracked</div>
            <div className="stat-card-sub">Relational SQLite Schema</div>
          </div>

          <div className="stat-overview-card">
            <div className="stat-card-top">
              <span className="stat-card-num">
                <AnimatedNumber value={14} duration={1000} />
              </span>
              <span className="stat-pill-tag">Continuity</span>
            </div>
            <div className="stat-card-label">Franchises</div>
            <div className="stat-card-sub">Active & Historic Teams</div>
          </div>
        </div>
      </div>

      {/* ── 3. CONTENT CONTAINER FOR BELOW-THE-FOLD SECTIONS ─────── */}
      <div className="home-content-container">
        {/* ── SECTION 2: INTERACTIVE HISTORICAL FIXTURE ARCHIVE ───── */}
        <section className="home-ticker-section" aria-label="Featured Historical Matchups">
          <div className="section-intro-bar">
            <div>
              <span className="section-kicker">Interactive Fixture Archive</span>
              <h2 className="section-heading-text">Historical Head-to-Head Rivalries</h2>
            </div>
            <span className="section-note">
              Click any fixture to instantly load pre-match parameters into the prediction engine
            </span>
          </div>

          <MatchStrip
            onQuickSelect={(t1, t2) => {
              if (onQuickSelect) onQuickSelect(t1, t2);
              setActivePage('prediction');
            }}
          />
        </section>

        {/* ── SECTION 3: RESEARCH SCOPE & TECHNICAL ARCHITECTURE ──── */}
        <section className="research-summary-section white-card" aria-labelledby="scope-heading">
          <div className="section-header-compact">
            <div className="header-icon-box">
              <IconDatabase size={20} />
            </div>
            <div>
              <h2 id="scope-heading" className="section-title-sm">
                Research Scope & Technical Architecture
              </h2>
              <p className="section-subtitle-sm">
                Standardized data pipeline engineered to eliminate lookahead bias and quantify probabilistic predictability
              </p>
            </div>
          </div>

          <div className="research-pillars-grid">
            {researchPillars.map((p, idx) => (
              <div key={idx} className="pillar-card">
                <div className="pillar-header">
                  <span className="pillar-icon">{p.icon}</span>
                  <h3 className="pillar-title">{p.title}</h3>
                </div>
                <p className="pillar-desc">{p.desc}</p>
              </div>
            ))}
          </div>

          <div className="methodology-note-banner">
            <IconCheckCircle size={18} className="note-icon" />
            <p className="note-text">
              <strong>Empirical Predictability Note:</strong> Because T20 cricket is inherently stochastic with high outcome variance, pre-match machine learning models operate near an empirical accuracy boundary of <strong>50%–54%</strong>. Rather than overstating deterministic accuracy, this platform provides calibrated probability distributions and transparent feature attribution.
            </p>
          </div>
        </section>

        {/* ── SECTION 4: MODEL INTELLIGENCE BENCHMARK PREVIEW ────── */}
        <section
          id="benchmarks-preview"
          className="benchmarks-preview-section white-card"
          aria-labelledby="benchmarks-heading"
        >
          <div className="benchmarks-section-header">
            <div>
              <div className="badge-tag">
                <IconSparkles size={13} style={{ marginRight: 5, verticalAlign: 'middle' }} />
                Out-of-Sample Evaluation
              </div>
              <h2 id="benchmarks-heading" className="section-title-sm">
                Algorithm Performance Benchmark
              </h2>
              <p className="section-subtitle-sm">
                Comparative metrics across all 12 evaluated models on chronological holdout test fixtures (2022–2024)
              </p>
            </div>

            <div className="benchmarks-controls">
              <div className="tab-pill-group" role="tablist">
                <button
                  type="button"
                  role="tab"
                  aria-selected={activeModelTab === 'all'}
                  className={`tab-pill ${activeModelTab === 'all' ? 'active' : ''}`}
                  onClick={() => setActiveModelTab('all')}
                >
                  All 12 Models
                </button>
                <button
                  type="button"
                  role="tab"
                  aria-selected={activeModelTab === 'top6'}
                  className={`tab-pill ${activeModelTab === 'top6' ? 'active' : ''}`}
                  onClick={() => setActiveModelTab('top6')}
                >
                  Top 6
                </button>
              </div>

              <button
                type="button"
                className="btn-secondary btn-sm"
                onClick={() => setActivePage('prediction')}
              >
                <span>Full Leaderboard & XAI</span>
                <IconArrowRight size={14} />
              </button>
            </div>
          </div>

          <div className="benchmarks-table-wrapper">
            <table className="benchmark-preview-table" aria-label="Machine Learning Model Comparison">
              <thead>
                <tr>
                  <th scope="col" className="col-rank">Rank</th>
                  <th scope="col" className="col-model">Model Algorithm</th>
                  <th scope="col" className="col-metric">Accuracy</th>
                  <th scope="col" className="col-metric">ROC-AUC</th>
                  <th scope="col" className="col-metric">F1 Score</th>
                  <th scope="col" className="col-metric">Precision</th>
                  <th scope="col" className="col-metric">Recall</th>
                  <th scope="col" className="col-bar">Performance Ratio</th>
                </tr>
              </thead>
              <tbody>
                {modelsToShow.map((m) => {
                  const acc = Number(m.Accuracy || 0);
                  const roc = Number(m.ROC_AUC || 0);
                  const f1 = Number(m.F1 || 0);
                  const prec = Number(m.Precision || 0);
                  const rec = Number(m.Recall || 0);
                  const isTop = m.Rank <= 3;

                  return (
                    <tr key={m.Model} className={isTop ? 'row-highlight' : ''}>
                      <td className="col-rank">
                        <span className={`rank-badge ${isTop ? 'top-rank' : ''}`}>
                          #{m.Rank}
                        </span>
                      </td>
                      <td className="col-model">
                        <span className="model-name">{m.Model}</span>
                        {isTop && <span className="top-pill">Top Tier</span>}
                      </td>
                      <td className="col-metric metric-primary">
                        {(acc * 100).toFixed(1)}%
                      </td>
                      <td className="col-metric">
                        {roc > 0 ? roc.toFixed(4) : '—'}
                      </td>
                      <td className="col-metric">
                        {f1 > 0 ? f1.toFixed(4) : '—'}
                      </td>
                      <td className="col-metric text-muted">
                        {prec > 0 ? prec.toFixed(4) : '—'}
                      </td>
                      <td className="col-metric text-muted">
                        {rec > 0 ? rec.toFixed(4) : '—'}
                      </td>
                      <td className="col-bar">
                        <div className="bar-track" aria-hidden="true">
                          <div
                            className="bar-fill"
                            style={{
                              width: `${Math.min(acc * 100, 100)}%`,
                              backgroundColor: isTop ? '#15803d' : '#4b5563',
                            }}
                          />
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          <div className="benchmarks-table-footer">
            <span className="footer-legend">
              Evaluated using out-of-sample historical holdout set (2022–2024 seasons). Pre-match features only. No in-play ball updates.
            </span>
            <button
              type="button"
              className="link-button"
              onClick={() => setActivePage('prediction')}
            >
              Configure Custom Predictions with Selected Algorithms →
            </button>
          </div>
        </section>

        {/* ── SECTION 5: PLATFORM ANALYTICAL MODULES ──────────────── */}
        <section className="home-features-section" aria-labelledby="suites-heading">
          <div className="section-intro-bar">
            <div>
              <span className="section-kicker">Analytics Architecture</span>
              <h2 id="suites-heading" className="section-heading-text">
                Platform Analytical Modules
              </h2>
            </div>
            <p className="section-note">
              Integrated research toolsets for franchise history, player records, empirical distributions, and scenario modeling
            </p>
          </div>

          <div className="features-grid">
            {features.map((f) => (
              <div
                key={f.id}
                className="feature-card white-card"
                onClick={() => setActivePage(f.id)}
                role="button"
                tabIndex={0}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    setActivePage(f.id);
                  }
                }}
              >
                <div className="feature-card-header">
                  <div className="feature-icon-wrapper">{f.icon}</div>
                  <span className="feature-badge">{f.badge}</span>
                </div>
                <h3 className="feature-title">{f.title}</h3>
                <p className="feature-desc">{f.desc}</p>
                <div className="feature-action-link">
                  <span>{f.actionText}</span>
                  <IconArrowRight size={14} className="action-arrow" />
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* ── SECTION 6: CINEMATIC PREDICTION CALL TO ACTION ──────── */}
        <section className="cinematic-cta-banner" aria-label="Start Predicting Match Outcomes">
          <div className="cta-banner-content">
            <div className="cta-badge">
              <span className="cta-dot" />
              <span>LIVE INTERACTIVE INFERENCE</span>
            </div>
            <h2 className="cta-heading">Ready to Predict Match Outcomes?</h2>
            <p className="cta-description">
              Select two franchises, match venue, and toss scenario to execute real-time multi-model
              consensus win probability estimation with explainable feature attribution.
            </p>
            <div className="cta-actions">
              <button
                type="button"
                className="btn-primary cta-main-btn"
                onClick={() => setActivePage('prediction')}
              >
                <IconTarget size={18} />
                <span>Launch Prediction Engine</span>
              </button>
              <button
                type="button"
                className="btn-secondary cta-sub-btn"
                onClick={() => setActivePage('probability-stats')}
              >
                <IconTrendingUp size={18} />
                <span>Explore Empirical Distributions</span>
              </button>
            </div>
          </div>
          <div className="cta-banner-bg-decoration" aria-hidden="true" />
        </section>
      </div>
    </div>
  );
}

