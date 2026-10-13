// Hero.jsx — Landing headline section
import React from 'react';
import './Hero.css';

export default function Hero({ totalMatches }) {
  return (
    <section className="hero">
      <div className="hero-eyebrow anim-fade-up">
        <span className="eyebrow-dot" />
        <span>17 Seasons · {totalMatches ? totalMatches.toLocaleString() : '1000+'} Matches · 9 ML Models</span>
      </div>

      <h1 className="hero-headline anim-fade-up delay-1">
        Predict the Game.
        <br />
        <span className="gradient-text">Own the Insight.</span>
      </h1>

      <p className="hero-sub anim-fade-up delay-2">
        An ensemble of 9 machine-learning models trained on 17 years of IPL data
        delivers calibrated pre-match win probabilities — with full explainability.
      </p>

      <div className="hero-stats anim-fade-up delay-3">
        <div className="hero-stat-item">
          <span className="hero-stat-value gradient-text">9</span>
          <span className="hero-stat-label">ML Models</span>
        </div>
        <div className="hero-stat-divider" />
        <div className="hero-stat-item">
          <span className="hero-stat-value gradient-text">15</span>
          <span className="hero-stat-label">Features</span>
        </div>
        <div className="hero-stat-divider" />
        <div className="hero-stat-item">
          <span className="hero-stat-value gradient-text">~72%</span>
          <span className="hero-stat-label">Best Accuracy</span>
        </div>
        <div className="hero-stat-divider" />
        <div className="hero-stat-item">
          <span className="hero-stat-value gradient-text">Zero</span>
          <span className="hero-stat-label">Target Leakage</span>
        </div>
      </div>

      <a href="#predict" className="btn-primary hero-cta anim-fade-up delay-4">
        <span>🔮</span> Start Predicting
      </a>

      {/* Decorative cricket pitch lines */}
      <div className="hero-pitch-deco" aria-hidden="true">
        <div className="pitch-line" />
        <div className="pitch-line" />
        <div className="pitch-crease" />
      </div>
    </section>
  );
}
