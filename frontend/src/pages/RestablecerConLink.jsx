import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import api from '../api/client';
import FondoBarras from '../components/FondoBarras';
import ReglasContraseña from '../components/ReglasContraseña';
import { contraseñaSegura } from '../utils/contraseña';
import './Login.css';

// Paso 2 de "Olvidé mi contraseña": es la pantalla que abre el link del mail
// (/restablecer-clave/<token>). Primero se fija si el link todavía sirve; si sirve,
// el usuario elige su contraseña nueva con las reglas de seguridad.
export default function RestablecerConLink() {
  const { token } = useParams();
  const [estado, setEstado] = useState('revisando'); // revisando | valido | vencido | listo
  const [nombre, setNombre] = useState('');
  const [contraseña, setContraseña] = useState('');
  const [confirmacion, setConfirmacion] = useState('');
  const [error, setError] = useState('');
  const [enviando, setEnviando] = useState(false);

  // Al abrir la página se revisa el link (puede haber vencido o ya haberse usado)
  useEffect(() => {
    api
      .get(`/restablecer-clave/${token}/`)
      .then(({ data }) => {
        setNombre(data.nombre);
        setEstado('valido');
      })
      .catch(() => setEstado('vencido'));
  }, [token]);

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    // Se revisa antes de mandar (el backend lo vuelve a controlar)
    if (!contraseñaSegura(contraseña)) {
      setError('La contraseña no cumple todos los requisitos de seguridad.');
      return;
    }
    if (contraseña !== confirmacion) {
      setError('Las contraseñas no coinciden.');
      return;
    }
    setEnviando(true);
    try {
      await api.post(`/restablecer-clave/${token}/`, { contraseña_nueva: contraseña });
      setEstado('listo');
    } catch (err) {
      const datos = err.response?.data;
      // Si justo venció mientras escribía, se pasa al aviso de link vencido
      if (datos?.detail) {
        setEstado('vencido');
      } else {
        setError(Array.isArray(datos?.contraseña_nueva) ? datos.contraseña_nueva.join(' ') : 'No se pudo guardar la contraseña.');
      }
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="login-page">
      <FondoBarras className="login-bars" />
      <form className="login-card" onSubmit={handleSubmit}>
        <h1>Nueva contraseña</h1>

        {estado === 'revisando' && <p className="login-subtitle">Revisando el link...</p>}

        {/* El link venció, ya se usó o no existe */}
        {estado === 'vencido' && (
          <>
            <div className="alert alert-error">
              El link venció o ya se usó. Los links duran 30 minutos y sirven una sola vez.
            </div>
            <Link to="/recuperar-clave" className="btn btn-primary login-submit">Pedir un link nuevo</Link>
          </>
        )}

        {/* Contraseña guardada: ya puede entrar */}
        {estado === 'listo' && (
          <>
            <div className="alert alert-success">Listo, tu contraseña se cambió. Ya podés iniciar sesión con la nueva.</div>
            <Link to="/login" className="btn btn-primary login-submit">Ir a iniciar sesión</Link>
          </>
        )}

        {/* Formulario para elegir la contraseña nueva */}
        {estado === 'valido' && (
          <>
            <p className="login-subtitle">Hola {nombre}, elegí tu contraseña nueva.</p>

            {error && <div className="alert alert-error">{error}</div>}

            <div className="form-field">
              <label htmlFor="nueva">Contraseña nueva</label>
              <input id="nueva" type="password" value={contraseña} onChange={(e) => setContraseña(e.target.value)} autoFocus required />
              {/* Requisitos que se van tildando mientras se escribe */}
              <ReglasContraseña contraseña={contraseña} />
            </div>

            <div className="form-field">
              <label htmlFor="confirmacion">Repetir contraseña nueva</label>
              <input id="confirmacion" type="password" value={confirmacion} onChange={(e) => setConfirmacion(e.target.value)} required />
              {confirmacion && confirmacion !== contraseña && (
                <span className="form-error">Las contraseñas no coinciden.</span>
              )}
            </div>

            <button type="submit" className="btn btn-primary login-submit" disabled={enviando}>
              {enviando ? 'Guardando...' : 'Guardar contraseña'}
            </button>
          </>
        )}

        {estado !== 'listo' && (
          <Link to="/login" className="login-link login-volver">Volver al inicio de sesión</Link>
        )}
      </form>
    </div>
  );
}
