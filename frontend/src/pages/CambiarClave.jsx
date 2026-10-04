import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api/client';
import { useAuth } from '../context/AuthContext';
import FondoBarras from '../components/FondoBarras';
import ReglasContraseña from '../components/ReglasContraseña';
import { contraseñaSegura } from '../utils/contraseña';
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

    // Antes de mandarla se revisa que cumpla todas las reglas (el backend lo vuelve a controlar)
    if (!contraseñaSegura(contraseñaNueva)) {
      setError('La contraseña nueva no cumple todos los requisitos de seguridad.');
      return;
    }
    if (contraseñaNueva === contraseñaActual) {
      setError('La contraseña nueva tiene que ser distinta de la provisoria.');
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
      // Si el backend rechaza la clave nueva, devuelve una lista con lo que falta: se muestra junta
      const datos = err.response?.data;
      setError(
        datos?.contraseña_actual?.[0] ||
        (Array.isArray(datos?.contraseña_nueva) ? datos.contraseña_nueva.join(' ') : null) ||
        datos?.detail ||
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
          {/* Requisitos que se van tildando mientras se escribe */}
          <ReglasContraseña contraseña={contraseñaNueva} />
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
          {/* Aviso en el momento si la repetición no coincide */}
          {confirmacion && confirmacion !== contraseñaNueva && (
            <span className="form-error">Las contraseñas no coinciden.</span>
          )}
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