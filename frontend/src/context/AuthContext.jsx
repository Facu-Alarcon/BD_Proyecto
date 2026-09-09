import { createContext, useContext, useEffect, useState } from 'react';
import api from '../api/client';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [usuario, setUsuario] = useState(() => {
    const raw = localStorage.getItem('infinito_usuario');
    return raw ? JSON.parse(raw) : null;
  });
  const [cargando, setCargando] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('infinito_token');
    if (!token) {
      setCargando(false);
      return;
    }
    api
      .get('/me/')
      .then(({ data }) => {
        setUsuario(data);
        localStorage.setItem('infinito_usuario', JSON.stringify(data));
      })
      .catch(() => setUsuario(null))
      .finally(() => setCargando(false));
  }, []);

  async function login(usuarioNombre, contraseña) {
    const { data } = await api.post('/login/', { usuario: usuarioNombre, contraseña });
    localStorage.setItem('infinito_token', data.token);
    localStorage.setItem('infinito_usuario', JSON.stringify(data.usuario));
    setUsuario(data.usuario);
    return data.usuario;
  }

  async function logout() {
    try {
      await api.post('/logout/');
    } catch {
      // el token ya puede haber expirado; igual limpiamos localmente
    }
    localStorage.removeItem('infinito_token');
    localStorage.removeItem('infinito_usuario');
    setUsuario(null);
  }

  return (
    <AuthContext.Provider value={{ usuario, login, logout, cargando }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
