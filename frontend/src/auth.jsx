import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { api } from './api.js';

// Holds the signed-in user for the whole app. user is null when nobody is signed in.
const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [checked, setChecked] = useState(false);

  // On first load, ask the server whether a session cookie is still valid.
  useEffect(() => {
    api
      .me()
      .then((data) => setUser(data))
      .catch(() => setUser(null))
      .finally(() => setChecked(true));
  }, []);

  const signIn = useCallback(async (username, password) => {
    await api.login(username, password);
    // Ask /me for the authoritative role (ROLE_...) instead of trusting the login body.
    const me = await api.me();
    setUser(me);
    return me;
  }, []);

  const signOut = useCallback(async () => {
    try {
      await api.logout();
    } finally {
      setUser(null);
    }
  }, []);

  return (
    <AuthContext.Provider value={{ user, checked, signIn, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}

// Maps the server role (ROLE_STUDENT, ...) to the route that belongs to it.
export function homeForRole(role) {
  switch (role) {
    case 'ROLE_STUDENT':
      return '/student';
    case 'ROLE_LECTURER':
      return '/lecturer';
    case 'ROLE_REGISTRAR':
      return '/registrar';
    case 'ROLE_AUDITOR':
      return '/auditor';
    default:
      return '/login';
  }
}
