import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth, homeForRole } from './auth.jsx';
import Login from './pages/Login.jsx';
import StudentPage from './pages/StudentPage.jsx';
import LecturerPage from './pages/LecturerPage.jsx';
import RegistrarPage from './pages/RegistrarPage.jsx';
import AuditorPage from './pages/AuditorPage.jsx';

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
            <StudentPage />
          </RequireRole>
        }
      />
      <Route
        path="/lecturer"
        element={
          <RequireRole role="ROLE_LECTURER">
            <LecturerPage />
          </RequireRole>
        }
      />
      <Route
        path="/registrar"
        element={
          <RequireRole role="ROLE_REGISTRAR">
            <RegistrarPage />
          </RequireRole>
        }
      />
      <Route
        path="/auditor"
        element={
          <RequireRole role="ROLE_AUDITOR">
            <AuditorPage />
          </RequireRole>
        }
      />
      <Route path="*" element={<Navigate to="/login" replace />} />
    </Routes>
  );
}
