// Dónde se guarda la sesión (el token y los datos del usuario) en el navegador.
// Depende del casillero "Recordarme" del login:
//   - tildado    -> localStorage: la sesión sigue abierta aunque se cierre el navegador
//   - sin tildar -> sessionStorage: la sesión se borra sola al cerrar el navegador
// Todo el resto de la app usa estas funciones y no toca el almacenamiento directamente.

const TOKEN = 'infinito_token';
const USUARIO = 'infinito_usuario';

// El almacenamiento donde está guardada la sesión actual (o null si no hay sesión)
function almacenActual() {
  if (localStorage.getItem(TOKEN)) return localStorage;
  if (sessionStorage.getItem(TOKEN)) return sessionStorage;
  return null;
}

export function leerToken() {
  return almacenActual()?.getItem(TOKEN) || null;
}

export function leerUsuario() {
  const raw = almacenActual()?.getItem(USUARIO);
  return raw ? JSON.parse(raw) : null;
}

// Guarda la sesión al iniciar sesión. Antes se borra cualquier sesión anterior, para que
// no queden dos guardadas (una en cada almacenamiento).
export function guardarSesion(token, usuario, recordarme) {
  borrarSesion();
  const almacen = recordarme ? localStorage : sessionStorage;
  almacen.setItem(TOKEN, token);
  almacen.setItem(USUARIO, JSON.stringify(usuario));
}

// Actualiza los datos del usuario en el mismo lugar donde está guardada la sesión
export function guardarUsuario(usuario) {
  almacenActual()?.setItem(USUARIO, JSON.stringify(usuario));
}

export function borrarSesion() {
  for (const almacen of [localStorage, sessionStorage]) {
    almacen.removeItem(TOKEN);
    almacen.removeItem(USUARIO);
  }
}
