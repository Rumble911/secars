import { useEffect, useState } from 'react';
import Shell from '../components/Shell.jsx';
import { useAuth } from '../auth.jsx';
import { api, fmtDate } from '../api.js';

// Registrar: publishes submitted sections, requests grade changes after closure,
// and decides other registrars' requests (the server refuses your own).
export default function RegistrarPage() {
  const { user } = useAuth();
  const [offerings, setOfferings] = useState(null);
  const [pending, setPending] = useState(null);
  const [selected, setSelected] = useState(null);
  const [students, setStudents] = useState([]);
  const [changes, setChanges] = useState({});
  const [decisionNotes, setDecisionNotes] = useState({});
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  useEffect(() => {
    refreshAll();
  }, []);

  async function refreshAll() {
    setError('');
    try {
      const [o, p] = await Promise.all([api.registrarOfferings(), api.pendingChanges()]);
      setOfferings(o);
      setPending(p);
    } catch (e) {
      setError(e.message);
    }
  }

  async function openSection(offering) {
    setSelected(offering);
    setChanges({});
    setError('');
    setNotice('');
    try {
      setStudents(await api.registrarEnrollments(offering.offering_id));
    } catch (e) {
      setError(e.message);
    }
  }

  async function publish(offering) {
    setError('');
    setNotice('');
    try {
      await api.publishOffering(offering.offering_id);
      setNotice(`Published ${offering.code} section ${offering.section_no}`);
      await refreshAll();
      if (selected && selected.offering_id === offering.offering_id) {
        setSelected({ ...selected, status: 'PUBLISHED' });
      }
    } catch (e) {
      setError(e.message);
    }
  }

  async function requestChange(row) {
    const draft = changes[row.enrollment_id] || {};
    setError('');
    setNotice('');
    try {
      await api.requestChange(row.enrollment_id, Number(draft.grade), draft.reason || '');
      setNotice(`Change requested for ${row.full_name}`);
      setChanges((c) => {
        const next = { ...c };
        delete next[row.enrollment_id];
        return next;
      });
      await refreshAll();
    } catch (e) {
      setError(e.message);
    }
  }

  async function decide(request, approve) {
    setError('');
    setNotice('');
    try {
      await api.decideChange(request.request_id, approve, decisionNotes[request.request_id] || '');
      setNotice(approve ? 'Change approved and applied' : 'Change rejected');
      await refreshAll();
    } catch (e) {
      setError(e.message);
    }
  }

  const closed = selected && selected.status !== 'OPEN';

  return (
    <Shell title="Registrar portal">
      {error && <p className="error" role="alert">{error}</p>}
      {notice && <p className="notice" role="status">{notice}</p>}

      <section className="card">
        <h2>Sections</h2>
        {offerings === null && <p className="muted">Loading...</p>}
        {offerings && (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Term</th>
                  <th>Code</th>
                  <th>Section</th>
                  <th>Lecturer</th>
                  <th>Status</th>
                  <th>Enrolled</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {offerings.map((o) => (
                  <tr key={o.offering_id}>
                    <td>{o.term}</td>
                    <td>{o.code}</td>
                    <td>{o.section_no}</td>
                    <td>{o.lecturer_name}</td>
                    <td><span className="badge">{o.status}</span></td>
                    <td>{o.enrolled}</td>
                    <td className="actions">
                      <button className="small secondary" onClick={() => openSection(o)}>Students</button>
                      {o.status === 'SUBMITTED' && (
                        <button className="small" onClick={() => publish(o)}>Publish</button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {selected && (
        <section className="card">
          <div className="row-between">
            <h2>{selected.code} section {selected.section_no} - students</h2>
            <button className="secondary" onClick={() => setSelected(null)}>Close</button>
          </div>
          <p className="muted">
            <span className="badge">{selected.status}</span>
            {closed ? ' · closed: changes need a second registrar to approve' : ' · open: the lecturer edits grades'}
          </p>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Student ID</th>
                  <th>Name</th>
                  <th>Grade</th>
                  {closed && <th>Request change</th>}
                </tr>
              </thead>
              <tbody>
                {students.map((s) => (
                  <tr key={s.enrollment_id}>
                    <td>{s.student_id}</td>
                    <td>{s.full_name}</td>
                    <td>{s.grade ?? <span className="muted">Not entered</span>}</td>
                    {closed && (
                      <td>
                        <div className="inline-form">
                          <input
                            className="grade-input"
                            type="number"
                            min="0"
                            max="100"
                            step="0.01"
                            placeholder="New"
                            value={changes[s.enrollment_id]?.grade ?? ''}
                            onChange={(e) => setChanges({
                              ...changes,
                              [s.enrollment_id]: { ...changes[s.enrollment_id], grade: e.target.value },
                            })}
                          />
                          <input
                            className="reason-input"
                            placeholder="Reason (min 10 characters)"
                            value={changes[s.enrollment_id]?.reason ?? ''}
                            onChange={(e) => setChanges({
                              ...changes,
                              [s.enrollment_id]: { ...changes[s.enrollment_id], reason: e.target.value },
                            })}
                          />
                          <button className="small" onClick={() => requestChange(s)}>Request</button>
                        </div>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      <section className="card">
        <h2>Pending grade-change requests</h2>
        {pending === null && <p className="muted">Loading...</p>}
        {pending && pending.length === 0 && <p className="muted">Nothing waiting for a decision.</p>}
        {pending && pending.length > 0 && (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>#</th>
                  <th>Student</th>
                  <th>Course</th>
                  <th>Grade</th>
                  <th>Reason</th>
                  <th>Requested by</th>
                  <th>When</th>
                  <th>Decision</th>
                </tr>
              </thead>
              <tbody>
                {pending.map((r) => {
                  const mine = r.requested_by === user.username;
                  return (
                    <tr key={r.request_id}>
                      <td>{r.request_id}</td>
                      <td>{r.full_name}</td>
                      <td>{r.code}</td>
                      <td>{r.old_grade ?? '-'} → {r.new_grade}</td>
                      <td>{r.reason}</td>
                      <td>{r.requested_by}</td>
                      <td>{fmtDate(r.requested_at)}</td>
                      <td>
                        {mine ? (
                          <span className="muted">Waiting for another registrar</span>
                        ) : (
                          <div className="inline-form">
                            <input
                              className="reason-input"
                              placeholder="Note (optional)"
                              value={decisionNotes[r.request_id] ?? ''}
                              onChange={(e) => setDecisionNotes({ ...decisionNotes, [r.request_id]: e.target.value })}
                            />
                            <button className="small" onClick={() => decide(r, true)}>Approve</button>
                            <button className="small secondary" onClick={() => decide(r, false)}>Reject</button>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </Shell>
  );
}
