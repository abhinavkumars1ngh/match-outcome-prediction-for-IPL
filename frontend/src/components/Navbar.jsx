// Navbar.jsx — IPL Info Cricket Analytics Navigation
import React from 'react';
import './Navbar.css';

export default function Navbar({ activePage, setActivePage, apiOnline }) {
  const navItems = [
    { id: 'home', label: 'Home', icon: '🏠' },
    { id: 'teams', label: 'Teams', icon: '🛡️' },
    { id: 'stats', label: 'Stats', icon: '📊' },
    { id: 'probability-stats', label: 'Probability & Stats', icon: '📈' },
    { id: 'players', label: 'Players', icon: '👤' },
    { id: 'my11', label: 'MY11', icon: '🏏' },
    { id: 'batter-bowler', label: 'Batsman vs Bowler', icon: '⚔️' },
    { id: 'prediction', label: 'Prediction', icon: '🔮' },
  ];

  return (
    <nav className="navbar">
      <div className="navbar-inner">
        {/* Brand */}
        <div className="navbar-brand" onClick={() => setActivePage('home')} style={{ cursor: 'pointer' }}>
          <img src="/ipl_info_logo.png" alt="IPL Info Logo" className="brand-logo" />
          <div className="brand-text">
            <span className="brand-name">IPL info</span>
            <span className="brand-tag">Cricket Analytics & ML</span>
          </div>
        </div>

        {/* Nav Links */}
        <div className="navbar-links">
          {navItems.map((item) => (
            <button
              key={item.id}
              className={`nav-link ${activePage === item.id ? 'active' : ''}`}
              onClick={() => setActivePage(item.id)}
            >
              <span className="nav-icon">{item.icon}</span>
              <span>{item.label}</span>
            </button>
          ))}
        </div>

        {/* API Live Status */}
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
