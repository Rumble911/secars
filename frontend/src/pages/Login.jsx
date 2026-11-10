import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth, homeForRole } from '../auth.jsx';

export default function Login() {
  const { signIn } = useAuth();
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function onSubmit(e) {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      const me = await signIn(username.trim(), password);
      navigate(homeForRole(me.role), { replace: true });
    } catch {
      // Same message for every failure (wrong password, unknown user, locked account).
      setError('Invalid username or password');
    } finally {
      setBusy(false);
      setPassword('');
    }
  }

  return (
    <main className="login">
      <h1>SecARS</h1>
      <p className="muted">Secure Academic Records System</p>
      <form onSubmit={onSubmit} className="card">
        <label>
          Username
          <input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
            maxLength={50}
            required
          />
        </label>
        <label>
          Password
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            maxLength={200}
            required
          />
        </label>
        {error && <p className="error" role="alert">{error}</p>}
        <button type="submit" disabled={busy}>
          {busy ? 'Signing in...' : 'Sign in'}
        </button>
      </form>
    </main>
  );
}
