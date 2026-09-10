import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import FondoBarras from '../components/FondoBarras';
import './Login.css';

export default function Login() {
  const [usuario, setUsuario] = useState('');
  const [contraseña, setContraseña] = useState('');
  const [verContraseña, setVerContraseña] = useState(false);
  const [recordarme, setRecordarme] = useState(false);
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setEnviando(true);
    try {
      await login(usuario, contraseña);
      navigate('/', { replace: true });
    } catch (err) {
      if (err.response?.status === 401 || err.response?.status === 400) {
        setError('Usuario o contraseña incorrectos.');
      } else {
        setError('No se pudo conectar con el servidor.');
      }
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="login-page">
      <FondoBarras className="login-bars" />

      <form className="login-card" onSubmit={handleSubmit}>
        <h1>Iniciar sesión</h1>
        <p className="login-subtitle">Ingresá con tu usuario para acceder al sistema.</p>

        {error && <div className="alert alert-error">{error}</div>}

        <div className="form-field">
          <label htmlFor="usuario">Usuario</label>
          <input
            id="usuario"
            type="text"
            placeholder="nombre.apellido"
            value={usuario}
            onChange={(e) => setUsuario(e.target.value)}
            autoFocus
            required
          />
        </div>

        <div className="form-field">
          <label htmlFor="contraseña">Contraseña</label>
          <div className="password-field">
            <input
              id="contraseña"
              type={verContraseña ? 'text' : 'password'}
              placeholder="••••••••"
              value={contraseña}
              onChange={(e) => setContraseña(e.target.value)}
              required
            />
            <button
              type="button"
              className="password-toggle"
              onClick={() => setVerContraseña((v) => !v)}
              aria-label={verContraseña ? 'Ocultar contraseña' : 'Mostrar contraseña'}
              tabIndex={-1}
            >
              {verContraseña ? (
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M17.94 17.94A10.94 10.94 0 0 1 12 20c-7 0-11-8-11-8a20.3 20.3 0 0 1 5.06-6.06M9.9 4.24A10.94 10.94 0 0 1 12 4c7 0 11 8 11 8a20.32 20.32 0 0 1-3.22 4.4M14.12 14.12a3 3 0 1 1-4.24-4.24" />
                  <line x1="1" y1="1" x2="23" y2="23" />
                </svg>
              ) : (
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8Z" />
                  <circle cx="12" cy="12" r="3" />
                </svg>
              )}
            </button>
          </div>
        </div>

        <div className="login-row">
          <label className="login-checkbox">
            <input
              type="checkbox"
              checked={recordarme}
              onChange={(e) => setRecordarme(e.target.checked)}
            />
            Recordarme
          </label>
          <a href="#" onClick={(e) => e.preventDefault()} className="login-link">
            Olvidé mi contraseña
          </a>
        </div>

        <button type="submit" className="btn btn-primary login-submit" disabled={enviando}>
          {enviando ? 'Ingresando...' : 'Ingresar'}
        </button>

      </form>
    </div>
  );
}
