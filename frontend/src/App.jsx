import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth, homeForRole } from './auth.jsx';
import Login from './pages/Login.jsx';
import RolePage from './pages/RolePage.jsx';

// Only signed-in users with the matching role may see a role page.
// Anything else goes back to the login screen. The server enforces the same rule.
function RequireRole({ role, children }) {
  const { user, checked } = useAuth();
  if (!checked) return <p className="center">Loading...</p>;
  if (!user) return <Navigate to="/login" replace />;
  if (user.role !== role) return <Navigate to={homeForRole(user.role)} replace />;
  return children;
}

export default function App() {
  const { user, checked } = useAuth();

  return (
    <Routes>
      <Route
        path="/login"
        element={
          !checked ? (
            <p className="center">Loading...</p>
          ) : user ? (
            <Navigate to={homeForRole(user.role)} replace />
          ) : (
            <Login />
          )
        }
      />
      <Route
        path="/student"
        element={
          <RequireRole role="ROLE_STUDENT">
            <RolePage title="Student" />
          </RequireRole>
        }
      />
      <Route
        path="/lecturer"
        element={
          <RequireRole role="ROLE_LECTURER">
            <RolePage title="Lecturer" />
          </RequireRole>
        }
      />
      <Route
        path="/registrar"
        element={
          <RequireRole role="ROLE_REGISTRAR">
            <RolePage title="Registrar" />
          </RequireRole>
        }
      />
      <Route
        path="/auditor"
        element={
          <RequireRole role="ROLE_AUDITOR">
            <RolePage title="Auditor" />
          </RequireRole>
        }
      />
      <Route path="*" element={<Navigate to="/login" replace />} />
    </Routes>
  );
}
