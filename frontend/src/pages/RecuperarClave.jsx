import { Link } from 'react-router-dom';
import FondoBarras from '../components/FondoBarras';
import './Login.css';

// "Olvidé mi contraseña": el usuario tiene que pedirle al administrador que le restablezca
// la clave. El administrador lo hace desde Usuarios (botón "Restablecer clave"): el sistema
// genera una contraseña temporal y, al ingresar con ella, le pide que elija una propia.
export default function RecuperarClave() {
  return (
    <div className="login-page">
      <FondoBarras className="login-bars" />
      <div className="login-card">
        <h1>Recuperar contraseña</h1>

        <div className="alert alert-success">
          Avisale al administrador del sistema que olvidaste tu contraseña.
        </div>
        <p className="login-subtitle">
          El administrador te va a dar una contraseña temporal. Cuando ingreses con ella, el
          sistema te va a pedir que elijas una contraseña nueva.
        </p>

        <Link to="/login" className="login-link login-volver">Volver al inicio de sesión</Link>
      </div>
    </div>
  );
}
