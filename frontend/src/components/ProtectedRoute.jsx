import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

// Protege las pantallas que necesitan sesión iniciada (ver App.jsx):
//   - mientras se confirma la sesión, muestra "Cargando...";
//   - si no hay sesión, manda al login;
//   - si el usuario tiene que cambiar la clave (contraseña temporal), lo manda a cambiarla
//     y no lo deja entrar a ninguna otra pantalla hasta que lo haga.
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