// Navbar.jsx
import React from 'react';
import './Navbar.css';

export default function Navbar({ apiOnline }) {
  return (
    <nav className="navbar">
      <div className="navbar-inner">
        {/* Brand */}
        <div className="navbar-brand">
          <div className="brand-icon">🏏</div>
          <div className="brand-text">
            <span className="brand-name">IPL Oracle</span>
            <span className="brand-tag">ML Prediction Engine</span>
          </div>
        </div>

        {/* Nav links */}
        <div className="navbar-links">
          <a href="#predict" className="nav-link">Predict</a>
          <a href="#h2h" className="nav-link">Head-to-Head</a>
          <a href="#models" className="nav-link">Models</a>
          <a href="#insights" className="nav-link">Insights</a>
        </div>

        {/* Status */}
        <div className="navbar-status">
          <div className={`api-status ${apiOnline === true ? 'online' : apiOnline === false ? 'offline' : 'checking'}`}>
            <span className="status-dot" />
            <span className="status-text">
              {apiOnline === true ? 'API Live' : apiOnline === false ? 'API Offline' : 'Connecting…'}
            </span>
          </div>
        </div>
      </div>
    </nav>
  );
}
