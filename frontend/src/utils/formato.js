// Funciones para mostrar datos más fáciles de leer en pantalla.
// Solo cambian cómo se ven: en la base se siguen guardando sin puntos ni espacios.

// DNI con puntos de miles: "30731178" -> "30.731.178", "7654321" -> "7.654.321"
export function formatearDni(dni) {
  if (!dni) return '';
  return String(dni).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

// Teléfono de 10 dígitos separado como se dice en voz alta:
// "3874731178" -> "387 473-1178" (característica, y el número partido en dos).
// Si tiene otro largo (11 o 12 dígitos) se deja como está para no separarlo mal.
export function formatearTelefono(telefono) {
  const t = String(telefono || '');
  if (/^\d{10}$/.test(t)) return `${t.slice(0, 3)} ${t.slice(3, 6)}-${t.slice(6)}`;
  return t;
}
