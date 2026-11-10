import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../auth.jsx';
import { api } from '../api.js';

// Student portal: the signed-in student's own enrolments and grades.
// Grades are shown only after the offering is published (the server decides; the UI just displays).
export default function StudentPage() {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    api
      .myEnrollments()
      .then((data) => setRows(data))
      .catch(() => setError('Could not load your courses. Please sign in again.'))
      .finally(() => setLoading(false));
  }, []);

  async function onLogout() {
    await signOut();
    navigate('/login', { replace: true });
  }

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <h1>Student portal</h1>
          <p className="muted">Signed in as {user.username}</p>
        </div>
        <button className="secondary" onClick={onLogout}>
          Sign out
        </button>
      </header>

      <section className="card">
        <h2>My courses</h2>
        {loading && <p className="muted">Loading...</p>}
        {error && <p className="error" role="alert">{error}</p>}
        {!loading && !error && rows.length === 0 && (
          <p className="muted">No enrolments yet.</p>
        )}
        {!loading && !error && rows.length > 0 && (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Term</th>
                  <th>Code</th>
                  <th>Course</th>
                  <th>Hours</th>
                  <th>Section</th>
                  <th>Lecturer</th>
                  <th>Grade</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={`${r.term}-${r.courseCode}-${r.sectionNo}`}>
                    <td>{r.term}</td>
                    <td>{r.courseCode}</td>
                    <td>{r.courseTitle}</td>
                    <td>{r.creditHours}</td>
                    <td>{r.sectionNo}</td>
                    <td>{r.lecturerName}</td>
                    <td>
                      {r.grade !== null ? r.grade : <span className="muted">Not published</span>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </main>
  );
}
