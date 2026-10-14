// ============================================================
// api.js — Complete API client for IPL Info Cricket Analytics
// ============================================================

const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000';

function unwrapR(obj) {
  if (obj === null || obj === undefined) return obj;
  if (Array.isArray(obj)) {
    return obj.map(unwrapR);
  }
  if (typeof obj === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(obj)) {
      if (Array.isArray(v) && v.length === 1 && (typeof v[0] === 'string' || typeof v[0] === 'number' || typeof v[0] === 'boolean')) {
        out[k] = v[0];
      } else {
        out[k] = unwrapR(v);
      }
    }
    return out;
  }
  return obj;
}

const request = async (path, options = {}) => {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ message: `HTTP ${res.status}` }));
    throw new Error(err.message || `Request failed with status ${res.status}`);
  }
  const data = await res.json();
  return unwrapR(data);
};

export const api = {
  health: () => request('/api/health'),
  teams:  () => request('/api/teams'),
  teamDetail: (teamId) => request(`/api/teams/${encodeURIComponent(teamId)}`),
  venues: () => request('/api/venues'),
  models: () => request('/api/models'),

  h2h: (team1, team2) =>
    request(`/api/h2h?team1=${encodeURIComponent(team1)}&team2=${encodeURIComponent(team2)}`),

  predict: (payload) =>
    request('/api/predict', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),

  players: (search = '', limit = 30, role = '') => {
    const q = new URLSearchParams();
    if (search) q.set('search', search);
    if (limit) q.set('limit', limit);
    if (role && role !== 'All') q.set('role', role);
    return request(`/api/players?${q.toString()}`);
  },

  playerProfile: (playerId) =>
    request(`/api/players/${encodeURIComponent(playerId)}`),

  stats: (season = '', team = '') => {
    const q = new URLSearchParams();
    if (season) q.set('season', season);
    if (team) q.set('team', team);
    return request(`/api/stats?${q.toString()}`);
  },

  batterBowler: (batsman, bowler, venue = '', phase = '') => {
    const q = new URLSearchParams();
    q.set('batsman', batsman);
    q.set('bowler', bowler);
    if (venue && venue !== 'All' && venue !== 'All Venues') q.set('venue', venue);
    if (phase && phase !== 'all') q.set('phase', phase);
    return request(`/api/batter-bowler?${q.toString()}`);
  },

  my11: (payload) =>
    request('/api/my11', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),

  probabilityStats: (filters = {}) => {
    const q = new URLSearchParams();
    if (filters.season && filters.season !== 'All') q.set('season', filters.season);
    if (filters.team && filters.team !== 'All') q.set('team', filters.team);
    if (filters.venue && filters.venue !== 'All') q.set('venue', filters.venue);
    if (filters.match_type && filters.match_type !== 'All') q.set('match_type', filters.match_type);
    return request(`/api/probability-stats?${q.toString()}`);
  },
};
