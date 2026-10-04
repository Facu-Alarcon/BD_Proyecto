// Circulito con las iniciales de una persona (ej: "Laura Alarcón" -> "LA").
// Se usa en todas las tablas que muestran nombres, así se ven todas iguales.

// Arma las iniciales. Si viene el apellido por separado se usa la primera letra de cada uno.
// Si viene todo junto en un solo texto ("Ayelén Saez") se toma la primera y la última palabra,
// así "María José Pérez" queda "MP" y no "MJ".
function iniciales(nombre, apellido) {
  const palabras = apellido
    ? [nombre?.trim().split(/\s+/)[0], apellido.trim().split(/\s+/)[0]]
    : (nombre || '').trim().split(/\s+/);
  const elegidas = palabras.length > 1 ? [palabras[0], palabras[palabras.length - 1]] : palabras;
  return elegidas
    .filter(Boolean)
    .map((p) => p[0].toUpperCase())
    .join('');
}

// Solo el circulito
export default function Avatar({ nombre, apellido }) {
  return (
    <span className="avatar-badge" aria-hidden="true">
      {iniciales(nombre, apellido)}
    </span>
  );
}

// Celda de tabla con el circulito, el nombre en negrita y, si hace falta, un texto chico abajo
// (por ejemplo el nombre del evento en Reservas). 'texto' sirve para mostrar el nombre
// con otro formato, como "Pérez, Juan" en Usuarios.
export function PersonaCelda({ nombre, apellido, texto, detalle }) {
  return (
    <div className="persona-celda">
      <Avatar nombre={nombre} apellido={apellido} />
      <div>
        <div className="persona-celda-nombre">{texto || [nombre, apellido].filter(Boolean).join(' ')}</div>
        {detalle && <div className="persona-celda-detalle">{detalle}</div>}
      </div>
    </div>
  );
}
