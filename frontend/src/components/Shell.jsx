import { useNavigate } from 'react-router-dom';
import { useAuth } from '../auth.jsx';

// Common frame for every signed-in screen: title, who is signed in, and sign out.
export default function Shell({ title, children }) {
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
          <h1>{title}</h1>
          <p className="muted">Signed in as {user.username}</p>
        </div>
        <button className="secondary" onClick={onLogout}>
          Sign out
        </button>
      </header>
      {children}
    </main>
  );
}
