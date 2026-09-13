import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function ProtectedRoute({ children }) {
  const { usuario, cargando } = useAuth();
  const location = useLocation();

  if (cargando) {
    return <div style={{ padding: 40 }}>Cargando...</div>;
  }
  if (!usuario) {
    return <Navigate to="/login" replace />;
  }
  if (usuario.debe_cambiar_clave && location.pathname !== '/cambiar-clave') {
    return <Navigate to="/cambiar-clave" replace />;
  }
  return children;
}