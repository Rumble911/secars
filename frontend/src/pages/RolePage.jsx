import { useNavigate } from 'react-router-dom';
import { useAuth } from '../auth.jsx';

// Shell shared by the four role screens. The data panels are filled in as the
// matching backend endpoints are built (see the list in the panel below).
export default function RolePage({ title }) {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();

  async function onLogout() {
    await signOut();
    navigate('/login', { replace: true });
  }

  return (
    <main className="shell">
      <header className="topbar">
        <div>
          <h1>{title} portal</h1>
          <p className="muted">Signed in as {user.username}</p>
        </div>
        <button className="secondary" onClick={onLogout}>
          Sign out
        </button>
      </header>

      <section className="card">
        <h2>Coming next</h2>
        <p className="muted">
          This screen is connected to the sign-in and role check. The data views for {title.toLowerCase()} are
          added once their backend endpoints exist.
        </p>
      </section>
    </main>
  );
}
