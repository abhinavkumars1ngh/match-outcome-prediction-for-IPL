// ============================================================
// api.js — All calls to the R Plumber backend on port 8000
// ============================================================

const BASE_URL = 'http://127.0.0.1:8000';

const request = async (path, options = {}) => {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ message: `HTTP ${res.status}` }));
    throw new Error(err.message || `Request failed with status ${res.status}`);
  }
  return res.json();
};

export const api = {
  health: () => request('/api/health'),
  teams:  () => request('/api/teams'),
  venues: () => request('/api/venues'),
  models: () => request('/api/models'),

  h2h: (team1, team2) =>
    request(`/api/h2h?team1=${encodeURIComponent(team1)}&team2=${encodeURIComponent(team2)}`),

  predict: (payload) =>
    request('/api/predict', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),
};
