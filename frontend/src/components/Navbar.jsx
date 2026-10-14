// Navbar.jsx — Professional Enterprise Navigation for IPL Match Outcome Prediction Platform
import React from 'react';
import {
  IconHome,
  IconShield,
  IconBarChart,
  IconTrendingUp,
  IconUser,
  IconUsers,
  IconSwords,
  IconTarget,
} from './Icons';
import './Navbar.css';

export default function Navbar({ activePage, setActivePage, apiOnline }) {
  const navItems = [
    { id: 'home', label: 'Home', icon: <IconHome size={15} /> },
    { id: 'teams', label: 'Franchises', icon: <IconShield size={15} /> },
    { id: 'stats', label: 'Tournament Stats', icon: <IconBarChart size={15} /> },
    { id: 'probability-stats', label: 'Probability & Distributions', icon: <IconTrendingUp size={15} /> },
    { id: 'players', label: 'Players', icon: <IconUser size={15} /> },
    { id: 'my11', label: 'MY11 Simulation', icon: <IconUsers size={15} /> },
    { id: 'batter-bowler', label: 'Matchups (H2H)', icon: <IconSwords size={15} /> },
    { id: 'prediction', label: 'Prediction', icon: <IconTarget size={15} /> },
  ];

  return (
    <header className="navbar" role="banner">
      <div className="navbar-inner">
        {/* Brand */}
        <button
          className="navbar-brand"
          onClick={() => setActivePage('home')}
          aria-label="Go to Homepage"
          type="button"
        >
          <img src="/ipl_info_logo.png" alt="IPL ML Platform" className="brand-logo" />
          <div className="brand-text">
            <span className="brand-name">IPL Info</span>
            <span className="brand-tag">IPL statistics Platform</span>
          </div>
        </button>

        {/* Navigation Items (Strictly Emoji-Free) */}
        <nav className="navbar-links" aria-label="Main Navigation">
          {navItems.map((item) => {
            const isActive = activePage === item.id;
            return (
              <button
                key={item.id}
                className={`nav-link ${isActive ? 'active' : ''}`}
                onClick={() => setActivePage(item.id)}
                aria-current={isActive ? 'page' : undefined}
                type="button"
              >
                <span className="nav-icon" aria-hidden="true">{item.icon}</span>
                <span className="nav-label">{item.label}</span>
              </button>
            );
          })}
        </nav>

        {/* API Live Status Badge */}
        <div className="navbar-status">
          <div
            className={`api-status ${apiOnline === true ? 'online' : apiOnline === false ? 'offline' : 'checking'
              }`}
            title={
              apiOnline === true
                ? 'Backend API and R Plumber connection active'
                : apiOnline === false
                  ? 'Backend API disconnected (http://127.0.0.1:8000)'
                  : 'Verifying backend connection...'
            }
          >
            <span className="status-dot" aria-hidden="true" />
            <span className="status-text">
              {apiOnline === true ? 'API Live' : apiOnline === false ? 'API Offline' : 'Connecting…'}
            </span>
          </div>
        </div>
      </div>
    </header>
  );
}
