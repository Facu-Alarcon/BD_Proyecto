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

// Número de comprobante de una reserva: el id con ceros adelante (12 -> "000012")
export function numeroComprobante(id) {
  return String(id ?? '').padStart(6, '0');
}

// Montos en pesos con separador de miles argentino: 180000 -> "$ 180.000"
export function formatearPesos(monto) {
  return `$ ${Number(monto || 0).toLocaleString('es-AR', { maximumFractionDigits: 2 })}`;
}

// Fecha 'AAAA-MM-DD' -> '18/10/2026'
export function formatearFecha(fecha) {
  if (!fecha) return '—';
  const [anio, mes, dia] = fecha.slice(0, 10).split('-');
  return `${dia}/${mes}/${anio}`;
}

// Fecha y hora completas que manda la API (con zona horaria) -> '06/10/2026 10:07'
export function formatearFechaHora(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  const dos = (n) => String(n).padStart(2, '0');
  return `${dos(d.getDate())}/${dos(d.getMonth() + 1)}/${d.getFullYear()} ${dos(d.getHours())}:${dos(d.getMinutes())}`;
}

// Hora o duración 'HH:MM:SS' -> 'HH:MM'
export function horaCorta(hora) {
  return hora ? hora.slice(0, 5) : '—';
}
