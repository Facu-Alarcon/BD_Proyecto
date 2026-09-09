import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function ProtectedRoute({ children }) {
  const { usuario, cargando } = useAuth();

  if (cargando) {
    return <div style={{ padding: 40 }}>Cargando...</div>;
  }
  if (!usuario) {
    return <Navigate to="/login" replace />;
  }
  return children;
}
