// Los estados de equipo son un catálogo editable (se pueden agregar más
// desde el formulario de Equipos), así que el color se asigna por palabras
// clave conocidas y cualquier estado nuevo/custom queda en gris.
export function colorEstadoEquipo(nombre) {
  const n = (nombre || '').toLowerCase();
  if (n.includes('dispon')) return { badge: 'badge-green', bar: 'fill-green' };
  if (n.includes('uso') || n.includes('reserv')) return { badge: 'badge-amber', bar: 'fill-blue' };
  if (n.includes('repar') || n.includes('baja') || n.includes('roto')) return { badge: 'badge-red', bar: 'fill-red' };
  return { badge: 'badge-gray', bar: 'fill-gray' };
}
