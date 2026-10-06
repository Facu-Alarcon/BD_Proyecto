// Cliente para hablar con la API de Django. Todas las pantallas lo usan así:
//   api.get('/clientes/'), api.post('/reservas/', datos), api.put(...), api.delete(...)
// Axios arma el pedido, manda el token y convierte la respuesta de JSON a objeto.
import axios from 'axios';

// Dirección base de la API. Se puede cambiar con la variable VITE_API_URL (archivo .env de
// frontend); si no está, se usa el Django local del docker (puerto 8000).
const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:8000/api',
});

// Antes de cada pedido: si hay sesión iniciada, se agrega el token en el encabezado
// Authorization (así el backend sabe quién es, ver authentication.py)
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('infinito_token');
  if (token) {
    config.headers.Authorization = `Token ${token}`;
  }
  return config;
});

// Después de cada respuesta: si el backend dice 401 (sesión vencida o token inválido),
// se borra la sesión guardada y se manda al login. En el propio login no, porque ahí
// un 401 solo significa "usuario o contraseña incorrectos".
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 && window.location.pathname !== '/login') {
      localStorage.removeItem('infinito_token');
      localStorage.removeItem('infinito_usuario');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default api;
