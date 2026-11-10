import { useEffect, useState } from 'react';
import Shell from '../components/Shell.jsx';
import { api, fmtDate } from '../api.js';

// Auditor: read-only views of grade history and security events (FR07).
export default function AuditorPage() {
  const [tab, setTab] = useState('grades');
  const [grades, setGrades] = useState(null);
  const [events, setEvents] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setError('');
    try {
      const [g, e] = await Promise.all([api.auditGrades(), api.auditEvents()]);
      setGrades(g);
      setEvents(e);
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <Shell title="Auditor portal">
      {error && <p className="error" role="alert">{error}</p>}

      <section className="card">
        <div className="row-between">
          <div className="tabs">
            <button className={tab === 'grades' ? '' : 'secondary'} onClick={() => setTab('grades')}>
              Grade history
            </button>
            <button className={tab === 'events' ? '' : 'secondary'} onClick={() => setTab('events')}>
              Security events
            </button>
          </div>
          <button className="secondary" onClick={load}>Refresh</button>
        </div>
        <p className="muted">Latest 200 rows. Read only.</p>

        {tab === 'grades' && (
          <div className="table-wrap">
            {grades === null ? (
              <p className="muted">Loading...</p>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th>When</th>
                    <th>Actor</th>
                    <th>Role</th>
                    <th>Type</th>
                    <th>Enrolment</th>
                    <th>Old</th>
                    <th>New</th>
                    <th>Reason</th>
                  </tr>
                </thead>
                <tbody>
                  {grades.map((g, i) => (
                    <tr key={i}>
                      <td>{fmtDate(g.event_time)}</td>
                      <td>{g.actor}</td>
                      <td>{g.actor_role}</td>
                      <td>{g.change_type}</td>
                      <td>{g.enrollment_id}</td>
                      <td>{g.old_grade ?? '-'}</td>
                      <td>{g.new_grade ?? '-'}</td>
                      <td>{g.reason ?? ''}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}

        {tab === 'events' && (
          <div className="table-wrap">
            {events === null ? (
              <p className="muted">Loading...</p>
            ) : (
              <table>
                <thead>
                  <tr>
                    <th>When</th>
                    <th>Actor</th>
                    <th>Event</th>
                    <th>Outcome</th>
                    <th>IP</th>
                    <th>Details</th>
                  </tr>
                </thead>
                <tbody>
                  {events.map((ev, i) => (
                    <tr key={i}>
                      <td>{fmtDate(ev.event_time)}</td>
                      <td>{ev.actor ?? '-'}</td>
                      <td>{ev.event_type}</td>
                      <td>{ev.outcome}</td>
                      <td>{ev.source_ip ?? '-'}</td>
                      <td>{ev.details ?? ''}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}
      </section>
    </Shell>
  );
}
