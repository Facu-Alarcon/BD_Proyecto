import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api/client';
import { useAuth } from '../context/AuthContext';
import FondoBarras from '../components/FondoBarras';
import './Login.css';

export default function CambiarClave() {
  const [contraseñaActual, setContraseñaActual] = useState('');
  const [contraseñaNueva, setContraseñaNueva] = useState('');
  const [confirmacion, setConfirmacion] = useState('');
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);
  const { actualizarUsuario, logout } = useAuth();
  const navigate = useNavigate();

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');

    if (contraseñaNueva.length < 4) {
      setError('La contraseña nueva debe tener al menos 4 caracteres.');
      return;
    }
    if (contraseñaNueva !== confirmacion) {
      setError('Las contraseñas nuevas no coinciden.');
      return;
    }

    setEnviando(true);
    try {
      await api.post('/cambiar-clave/', {
        contraseña_actual: contraseñaActual,
        contraseña_nueva: contraseñaNueva,
      });
      actualizarUsuario({ debe_cambiar_clave: false });
      navigate('/', { replace: true });
    } catch (err) {
      setError(
        err.response?.data?.contraseña_actual?.[0] ||
        err.response?.data?.detail ||
        'No se pudo cambiar la contraseña.'
      );
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="login-page">
      <FondoBarras className="login-bars" />
      <form className="login-card" onSubmit={handleSubmit}>
        <h1>Cambiar contraseña</h1>
        <p className="login-subtitle">
          Por seguridad, tenés que definir una contraseña propia antes de continuar.
        </p>

        {error && <div className="alert alert-error">{error}</div>}

        <div className="form-field">
          <label htmlFor="actual">Contraseña provisoria</label>
          <input
            id="actual"
            type="password"
            value={contraseñaActual}
            onChange={(e) => setContraseñaActual(e.target.value)}
            autoFocus
            required
          />
        </div>

        <div className="form-field">
          <label htmlFor="nueva">Contraseña nueva</label>
          <input
            id="nueva"
            type="password"
            value={contraseñaNueva}
            onChange={(e) => setContraseñaNueva(e.target.value)}
            required
          />
        </div>

        <div className="form-field">
          <label htmlFor="confirmacion">Repetir contraseña nueva</label>
          <input
            id="confirmacion"
            type="password"
            value={confirmacion}
            onChange={(e) => setConfirmacion(e.target.value)}
            required
          />
        </div>

        <button type="submit" className="btn btn-primary login-submit" disabled={enviando}>
          {enviando ? 'Guardando...' : 'Cambiar contraseña'}
        </button>

        <button
          type="button"
          className="btn btn-secondary"
          style={{ width: '100%', justifyContent: 'center', marginTop: 8 }}
          onClick={logout}
        >
          Cerrar sesión
        </button>
      </form>
    </div>
  );
}