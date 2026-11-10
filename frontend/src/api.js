// Thin wrapper around fetch. Every call goes to the same origin (Vite proxies /api to Spring Boot),
// so the session cookie is sent. Changing requests send the CSRF token in the header the server names.

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

let csrf = null;

async function loadCsrf() {
  csrf = await request('/api/auth/csrf');
}

async function request(path, options = {}) {
  const method = options.method || 'GET';
  const headers = {};
  if (options.body !== undefined) headers['Content-Type'] = 'application/json';

  if (method !== 'GET') {
    if (!csrf) await loadCsrf();
    headers[csrf.headerName] = csrf.token;
  }

  const res = await fetch(path, {
    method,
    credentials: 'same-origin',
    headers,
    body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
  });

  if (res.status === 204) return null;

  let data = null;
  try {
    data = await res.json();
  } catch {
    data = null;
  }

  if (!res.ok) {
    // The server writes only rule messages or generic text here (FR09).
    throw new ApiError(res.status, (data && data.error) || 'Request failed');
  }
  return data;
}

export const api = {
  login: async (username, password) => {
    const data = await request('/api/auth/login', { method: 'POST', body: { username, password } });
    await loadCsrf();
    return data;
  },

  me: () => request('/api/auth/me'),

  logout: async () => {
    try {
      await request('/api/auth/logout', { method: 'POST' });
    } finally {
      csrf = null;
    }
  },

  // Student
  myEnrollments: () => request('/api/student/enrollments'),

  // Lecturer
  lecturerOfferings: () => request('/api/lecturer/offerings'),
  lecturerGrades: (offeringId) => request(`/api/lecturer/offerings/${offeringId}/grades`),
  setGrade: (enrollmentId, grade) =>
    request(`/api/lecturer/enrollments/${enrollmentId}/grade`, { method: 'PUT', body: { grade } }),
  submitOffering: (offeringId) =>
    request(`/api/lecturer/offerings/${offeringId}/submit`, { method: 'POST' }),

  // Registrar
  registrarOfferings: () => request('/api/registrar/offerings'),
  registrarEnrollments: (offeringId) => request(`/api/registrar/offerings/${offeringId}/enrollments`),
  publishOffering: (offeringId) =>
    request(`/api/registrar/offerings/${offeringId}/publish`, { method: 'POST' }),
  requestChange: (enrollmentId, newGrade, reason) =>
    request('/api/registrar/change-requests', {
      method: 'POST',
      body: { enrollmentId, newGrade, reason },
    }),
  pendingChanges: () => request('/api/registrar/change-requests/pending'),
  decideChange: (requestId, approve, note) =>
    request(`/api/registrar/change-requests/${requestId}/decision`, {
      method: 'POST',
      body: { approve, note },
    }),

  // Auditor (read only)
  auditGrades: () => request('/api/auditor/grade-audit'),
  auditEvents: () => request('/api/auditor/security-events'),
};

/** Formats a timestamp returned by the API. Returns '' for empty values. */
export function fmtDate(value) {
  if (value === null || value === undefined || value === '') return '';
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? String(value) : d.toLocaleString();
}
