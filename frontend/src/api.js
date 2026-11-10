// Thin wrapper around fetch. Every call sends the session cookie (same origin via the Vite proxy).
// Errors are returned as ApiError so screens can show one generic message and never reveal details.

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

async function request(path, options = {}) {
  const res = await fetch(path, {
    credentials: 'same-origin',
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    ...options,
  });

  if (!res.ok) {
    throw new ApiError(res.status, 'Request failed');
  }
  if (res.status === 204) return null;
  return res.json();
}

export const api = {
  login: (username, password) =>
    request('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    }),

  me: () => request('/api/auth/me'),

  logout: () => request('/api/auth/logout', { method: 'POST' }),
};
