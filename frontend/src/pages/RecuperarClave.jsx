import { useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../api/client';
import FondoBarras from '../components/FondoBarras';
import './Login.css';

// Paso 1 de "Olvidé mi contraseña": el usuario escribe su usuario y el sistema le manda
// por mail un link para elegir una contraseña nueva (ver RecuperarClaveView en api.py).
// La respuesta es siempre la misma, exista o no el usuario, para no revelar qué usuarios existen.
export default function RecuperarClave() {
  const [usuario, setUsuario] = useState('');
  const [mensaje, setMensaje] = useState('');
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setEnviando(true);
    try {
      const { data } = await api.post('/recuperar-clave/', { usuario: usuario.trim() });
      setMensaje(data.detail);
    } catch (err) {
      setError(err.response?.data?.detail || 'No se pudo conectar con el servidor.');
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="login-page">
      <FondoBarras className="login-bars" />
      <form className="login-card" onSubmit={handleSubmit}>
        <h1>Recuperar contraseña</h1>

        {/* Una vez enviado se muestra el aviso en lugar del formulario */}
        {mensaje ? (
          <>
            <div className="alert alert-success">{mensaje}</div>
            <p className="login-subtitle">
              Revisá tu correo (también la carpeta de spam). Si no te llega, avisale al administrador
              para que te restablezca la clave desde Usuarios.
            </p>
          </>
        ) : (
          <>
            <p className="login-subtitle">
              Escribí tu usuario (por ejemplo perezj) y te mandamos un mail con un link para elegir una
              contraseña nueva.
            </p>

            {error && <div className="alert alert-error">{error}</div>}

            <div className="form-field">
              <label htmlFor="usuario">Usuario</label>
              <input
                id="usuario"
                type="text"
                placeholder="Ej: perezj"
                value={usuario}
                onChange={(e) => setUsuario(e.target.value)}
                autoFocus
                required
              />
            </div>

            <button type="submit" className="btn btn-primary login-submit" disabled={enviando}>
              {enviando ? 'Enviando...' : 'Enviarme el link'}
            </button>
          </>
        )}

        <Link to="/login" className="login-link login-volver">Volver al inicio de sesión</Link>
      </form>
    </div>
  );
}
