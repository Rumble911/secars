import { useEffect, useState } from 'react';
import Shell from '../components/Shell.jsx';
import { api } from '../api.js';

// Lecturer: own sections only. Grades are editable only while the section is OPEN.
export default function LecturerPage() {
  const [offerings, setOfferings] = useState(null);
  const [selected, setSelected] = useState(null);
  const [grades, setGrades] = useState([]);
  const [drafts, setDrafts] = useState({});
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  useEffect(() => {
    loadOfferings();
  }, []);

  async function loadOfferings() {
    try {
      setOfferings(await api.lecturerOfferings());
    } catch (e) {
      setError(e.message);
    }
  }

  async function openSection(offering) {
    setSelected(offering);
    setDrafts({});
    setError('');
    setNotice('');
    try {
      setGrades(await api.lecturerGrades(offering.offering_id));
    } catch (e) {
      setError(e.message);
    }
  }

  async function saveGrade(row) {
    const raw = drafts[row.enrollment_id];
    if (raw === undefined || raw === '') {
      setError('Enter a grade between 0 and 100 first');
      return;
    }
    setError('');
    setNotice('');
    try {
      await api.setGrade(row.enrollment_id, Number(raw));
      setNotice(`Saved grade for ${row.full_name}`);
      setGrades(await api.lecturerGrades(selected.offering_id));
      setDrafts((d) => {
        const next = { ...d };
        delete next[row.enrollment_id];
        return next;
      });
    } catch (e) {
      setError(e.message);
    }
  }

  async function submitSection() {
    if (!window.confirm('Submit this section? Grades become read-only for you after this.')) return;
    setError('');
    try {
      await api.submitOffering(selected.offering_id);
      setNotice('Section submitted');
      await loadOfferings();
      const fresh = (await api.lecturerOfferings()).find((o) => o.offering_id === selected.offering_id);
      setSelected(fresh || null);
      setGrades(await api.lecturerGrades(selected.offering_id));
    } catch (e) {
      setError(e.message);
    }
  }

  const isOpen = selected && selected.status === 'OPEN';

  return (
    <Shell title="Lecturer portal">
      {error && <p className="error" role="alert">{error}</p>}
      {notice && <p className="notice" role="status">{notice}</p>}

      {!selected && (
        <section className="card">
          <h2>My sections</h2>
          {offerings === null && <p className="muted">Loading...</p>}
          {offerings && offerings.length === 0 && <p className="muted">No sections assigned.</p>}
          {offerings && offerings.length > 0 && (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Term</th>
                    <th>Code</th>
                    <th>Course</th>
                    <th>Section</th>
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
                      <td>{o.title}</td>
                      <td>{o.section_no}</td>
                      <td><span className="badge">{o.status}</span></td>
                      <td>{o.enrolled}</td>
                      <td>
                        <button className="small" onClick={() => openSection(o)}>Open</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      )}

      {selected && (
        <section className="card">
          <div className="row-between">
            <div>
              <h2>{selected.code} - {selected.title} (section {selected.section_no})</h2>
              <p className="muted">
                {selected.term} · <span className="badge">{selected.status}</span>
                {!isOpen && ' · grades are locked; changes go through the registrar'}
              </p>
            </div>
            <div className="actions">
              <button className="secondary" onClick={() => { setSelected(null); setError(''); setNotice(''); loadOfferings(); }}>
                Back
              </button>
              {isOpen && <button onClick={submitSection}>Submit section</button>}
            </div>
          </div>

          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Student ID</th>
                  <th>Name</th>
                  <th>Grade</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {grades.map((g) => (
                  <tr key={g.enrollment_id}>
                    <td>{g.student_id}</td>
                    <td>{g.full_name}</td>
                    <td>
                      {isOpen ? (
                        <input
                          className="grade-input"
                          type="number"
                          min="0"
                          max="100"
                          step="0.01"
                          value={drafts[g.enrollment_id] ?? (g.grade ?? '')}
                          onChange={(e) => setDrafts({ ...drafts, [g.enrollment_id]: e.target.value })}
                        />
                      ) : (
                        g.grade ?? <span className="muted">Not entered</span>
                      )}
                    </td>
                    <td>
                      {isOpen && (
                        <button className="small" onClick={() => saveGrade(g)}>Save</button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </Shell>
  );
}
