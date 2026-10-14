// MatchStrip.jsx — Cricbuzz-style match center ticker
import React from 'react';
import './MatchStrip.css';

const FEATURED_ENCOUNTERS = [
  { t1: 'MI', t2: 'CSK', label: 'El Clásico', record: 'MI 20 - 17 CSK', venue: 'Wankhede' },
  { t1: 'RCB', t2: 'KKR', label: 'Rivalry Derby', record: 'KKR 19 - 14 RCB', venue: 'Eden Gardens' },
  { t1: 'GT', t2: 'RR', label: 'Title Rematch', record: 'GT 4 - 1 RR', venue: 'Narendra Modi Stadium' },
  { t1: 'SRH', t2: 'DC', label: 'South vs North', record: 'SRH 12 - 11 DC', venue: 'Uppal Stadium' },
  { t1: 'CSK', t2: 'RCB', label: 'Southern Derby', record: 'CSK 21 - 10 RCB', venue: 'Chepauk' },
];

export default function MatchStrip({ onQuickSelect }) {
  return (
    <div className="match-strip-container anim-fade-up">
      <div className="match-strip-badge">
        <span className="live-dot" />
        <span>HISTORICAL H2H ARCHIVE</span>
      </div>
      <div className="match-strip-scroll">
        {FEATURED_ENCOUNTERS.map((m, idx) => (
          <button
            key={idx}
            className="match-chip"
            onClick={() => onQuickSelect && onQuickSelect(m.t1, m.t2)}
            title={`Click to load ${m.t1} vs ${m.t2}`}
          >
            <div className="match-chip-teams">
              <span className="chip-t1">{m.t1}</span>
              <span className="chip-vs">vs</span>
              <span className="chip-t2">{m.t2}</span>
            </div>
            <div className="match-chip-meta">
              <span className="chip-badge">{m.label}</span>
              <span className="chip-record">{m.record}</span>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}
