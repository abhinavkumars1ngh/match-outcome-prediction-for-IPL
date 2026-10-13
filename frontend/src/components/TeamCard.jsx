// TeamCard.jsx — Selectable team card with color badge
import React from 'react';
import './TeamCard.css';

export default function TeamCard({ team, selected, onSelect, side }) {
  const initial = team.short_name || team.name.substring(0, 3).toUpperCase();

  return (
    <button
      className={`team-card ${selected ? 'selected' : ''} ${side}`}
      onClick={() => onSelect(team)}
      aria-pressed={selected}
      id={`team-card-${team.short_name}`}
      style={{
        '--team-primary': team.primary_color,
        '--team-secondary': team.secondary_color,
      }}
    >
      {/* Color swatch badge */}
      <div className="team-avatar" style={{ background: `linear-gradient(135deg, ${team.primary_color}, ${team.secondary_color})` }}>
        <span className="team-initials">{initial}</span>
      </div>

      {/* Info */}
      <div className="team-info">
        <div className="team-name">{team.name}</div>
        <div className="team-meta">
          <span className="team-stat">{team.win_percentage}% wins</span>
          {team.titles > 0 && (
            <span className="team-titles">🏆 {team.titles}</span>
          )}
        </div>
      </div>

      {/* Selected indicator */}
      {selected && (
        <div className="team-selected-ring" />
      )}
    </button>
  );
}
