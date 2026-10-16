// Sesión del usuario, compartida con toda la aplicación (Context de React).
// Cualquier componente puede hacer const { usuario, login, logout } = useAuth()
// sin tener que pasarse los datos de padre a hijo.
//
// La sesión se guarda también en el navegador (infinito_token e infinito_usuario) para que
// no se pierda al recargar la página. Si se tildó "Recordarme" sigue abierta aunque se
// cierre el navegador; si no, se borra al cerrarlo (ver api/sesion.js).
import { createContext, useContext, useEffect, useState } from 'react';
import api from '../api/client';
import { borrarSesion, guardarSesion, guardarUsuario, leerToken, leerUsuario } from '../api/sesion';

const AuthContext = createContext(null);

// Envuelve a toda la app (ver App.jsx) y le da acceso a la sesión a todo lo que tiene adentro
export function AuthProvider({ children }) {
  // Arranca con el usuario que había guardado (si había), así no parpadea el login al recargar
  const [usuario, setUsuario] = useState(leerUsuario);
  // Mientras se confirma la sesión con el backend, las rutas protegidas muestran "Cargando..."
  const [cargando, setCargando] = useState(true);

  // Al abrir la app: si hay token, se le pregunta al backend quién es (/me/) para tener los
  // permisos actualizados (pueden haber cambiado desde la última vez). Si el token ya no
  // sirve, la sesión queda vacía y se va al login.
  useEffect(() => {
    const token = leerToken();
    if (!token) {
      setCargando(false);
      return;
    }
    api
      .get('/me/')
      .then(({ data }) => {
        setUsuario(data);
        guardarUsuario(data);
      })
      .catch(() => setUsuario(null))
      .finally(() => setCargando(false));
  }, []);

  // Inicia sesión: pide el token al backend y guarda la sesión ("recordarme" decide si
  // sobrevive al cierre del navegador). Si el usuario o la clave están mal, el error lo
  // atrapa la pantalla de Login para mostrar el mensaje.
  async function login(usuarioNombre, contraseña, recordarme = false) {
    const { data } = await api.post('/login/', { usuario: usuarioNombre, contraseña });
    guardarSesion(data.token, data.usuario, recordarme);
    setUsuario(data.usuario);
    return data.usuario;
  }

  // Cierra la sesión en el backend (borra el token) y localmente
  async function logout() {
    try {
      await api.post('/logout/');
    } catch {
      // el token ya puede haber expirado; igual limpiamos localmente
    }
    borrarSesion();
    setUsuario(null);
  }

  // Cambia algunos datos del usuario guardado sin volver a pedirlos (ej: después de cambiar
  // la clave se apaga debe_cambiar_clave)
  function actualizarUsuario(cambios) {
    setUsuario((actual) => {
      if (!actual) return actual;
      const nuevo = { ...actual, ...cambios };
      guardarUsuario(nuevo);
      return nuevo;
    });
  }

  return (
    <AuthContext.Provider value={{ usuario, login, logout, actualizarUsuario, cargando }}>
      {children}
    </AuthContext.Provider>
  );
}

// Atajo para usar la sesión desde cualquier componente
export function useAuth() {
  return useContext(AuthContext);
}