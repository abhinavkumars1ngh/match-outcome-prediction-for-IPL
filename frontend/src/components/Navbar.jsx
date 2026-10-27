// Navbar.jsx — Professional Cinematic Navigation for IPL Match Outcome Prediction Platform
import React, { useState, useEffect } from 'react';
import {
  IconHome,
  IconShield,
  IconBarChart,
  IconTrendingUp,
  IconUser,
  IconUsers,
  IconSwords,
  IconTarget,
  IconMenu,
  IconX,
} from './Icons';
import './Navbar.css';

export default function Navbar({ activePage, setActivePage, apiOnline }) {
  const [isScrolled, setIsScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 20);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  // Close mobile menu on resize to desktop
  useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth > 1024) {
        setMobileMenuOpen(false);
      }
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  const navItems = [
    { id: 'home', label: 'Home', icon: <IconHome size={15} /> },
    { id: 'teams', label: 'Franchises', icon: <IconShield size={15} /> },
    { id: 'stats', label: 'Tournament Stats', icon: <IconBarChart size={15} /> },
    { id: 'probability-stats', label: 'Probability & Distributions', icon: <IconTrendingUp size={15} /> },
    { id: 'players', label: 'Players', icon: <IconUser size={15} /> },
    { id: 'my11', label: 'MY11 Simulation', icon: <IconUsers size={15} /> },
    { id: 'batter-bowler', label: 'Matchups (H2H)', icon: <IconSwords size={15} /> },
    { id: 'prediction', label: 'Predictions', icon: <IconTarget size={15} /> },
  ];

  const handleNavClick = (id) => {
    setActivePage(id);
    setMobileMenuOpen(false);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <header className={`navbar ${isScrolled ? 'navbar--scrolled' : ''}`} role="banner">
      <div className="navbar-inner">
        {/* Brand */}
        <button
          className="navbar-brand"
          onClick={() => handleNavClick('home')}
          aria-label="Go to Homepage"
          type="button"
        >
          <div className="brand-logo-frame">
            <img src="/ipl_info_logo.png" alt="IPL Info Logo" className="brand-logo" />
            <div className="logo-glow" aria-hidden="true" />
          </div>
          <div className="brand-text">
            <div className="brand-name-row">
              <span className="brand-name">IPL Info</span>
              <span className="brand-version">PRO</span>
            </div>
            <span className="brand-tag">IPL Statistics Platform</span>
          </div>
        </button>

        {/* Desktop Navigation Links */}
        <nav className="navbar-links" aria-label="Main Navigation">
          {navItems.map((item) => {
            const isActive = activePage === item.id;
            return (
              <button
                key={item.id}
                className={`nav-link ${isActive ? 'active' : ''}`}
                onClick={() => handleNavClick(item.id)}
                aria-current={isActive ? 'page' : undefined}
                type="button"
              >
                <span className="nav-icon" aria-hidden="true">{item.icon}</span>
                <span className="nav-label">{item.label}</span>
                {isActive && <span className="nav-active-indicator" layoutid="activeNavIndicator" />}
              </button>
            );
          })}
        </nav>

        {/* Right side actions: API Status & Mobile Toggle */}
        <div className="navbar-actions">
          {/* API Live Status Badge */}
          <div
            className={`api-status ${apiOnline === true ? 'online' : apiOnline === false ? 'offline' : 'checking'}`}
            title={
              apiOnline === true
                ? 'Backend API and R Plumber connection active (http://127.0.0.1:8000)'
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

          {/* Mobile Menu Hamburger Button */}
          <button
            className="navbar-mobile-toggle"
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            aria-label={mobileMenuOpen ? 'Close navigation menu' : 'Open navigation menu'}
            aria-expanded={mobileMenuOpen}
            type="button"
          >
            {mobileMenuOpen ? <IconX size={20} /> : <IconMenu size={20} />}
          </button>
        </div>
      </div>

      {/* Mobile Navigation Drawer */}
      {mobileMenuOpen && (
        <div className="mobile-drawer" role="dialog" aria-modal="true" aria-label="Mobile Navigation">
          <div className="mobile-drawer-inner">
            {navItems.map((item) => {
              const isActive = activePage === item.id;
              return (
                <button
                  key={item.id}
                  className={`mobile-nav-link ${isActive ? 'active' : ''}`}
                  onClick={() => handleNavClick(item.id)}
                  aria-current={isActive ? 'page' : undefined}
                  type="button"
                >
                  <span className="mobile-nav-icon">{item.icon}</span>
                  <span className="mobile-nav-label">{item.label}</span>
                  {isActive && <span className="mobile-active-dot" />}
                </button>
              );
            })}
          </div>
        </div>
      )}
    </header>
  );
}
