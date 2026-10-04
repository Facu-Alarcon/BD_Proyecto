// Cuadradito con ícono que va a la izquierda del nombre en las tablas que no son de personas
// (para personas se usa el circulito con iniciales de Avatar.jsx).
// Qué ícono y qué color lleva cada fila se decide en utils/iconosModulos.js.

// Trazos de cada dibujo, en estilo línea sobre una grilla de 24x24
const TRAZOS = {
  onda: <path d="M4 10v4M8 7v10M12 4v16M16 8v8M20 11v2" />,
  microfono: (
    <>
      <rect x="9" y="2" width="6" height="12" rx="3" />
      <path d="M5 10v1a7 7 0 0 0 14 0v-1M12 18v4M8 22h8" />
    </>
  ),
  consola: <path d="M6 21v-7M6 10V3M12 21v-9M12 8V3M18 21v-5M18 12V3M4 14h4M10 8h4M16 16h4" />,
  foco: <path d="M9 18h6M10 22h4M12 2a7 7 0 0 0-4 12.7c.6.5 1 1.3 1 2.1V17h6v-.2c0-.8.4-1.6 1-2.1A7 7 0 0 0 12 2z" />,
  estructura: <path d="M6 22 12 2l6 20M8.2 15h7.6M10 9h4M8.2 15 14 9M10 9l5.8 6" />,
  destellos: <path d="M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9zM19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z" />,
  cable: <path d="M12 22v-5M9 8V2M15 8V2M18 8v5a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4V8z" />,
  musica: (
    <>
      <path d="M9 18V5l12-2v13" />
      <circle cx="6" cy="18" r="3" />
      <circle cx="18" cy="16" r="3" />
    </>
  ),
  auriculares: <path d="M3 18v-6a9 9 0 0 1 18 0v6M21 19a2 2 0 0 1-2 2h-1v-6h3zM3 19a2 2 0 0 0 2 2h1v-6H3z" />,
  maletin: (
    <>
      <rect x="2" y="7" width="20" height="14" rx="2" />
      <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16" />
    </>
  ),
  billete: (
    <>
      <rect x="2" y="6" width="20" height="12" rx="2" />
      <circle cx="12" cy="12" r="2" />
      <path d="M6 12h.01M18 12h.01" />
    </>
  ),
  transferencia: <path d="M7 7h13l-3-3M17 17H4l3 3" />,
  tarjeta: (
    <>
      <rect x="2" y="5" width="20" height="14" rx="2" />
      <path d="M2 10h20M6 15h4" />
    </>
  ),
  billetera: <path d="M19 7V5a2 2 0 0 0-2-2H5a2 2 0 0 0 0 4h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5M16 14h.01" />,
  ojo: (
    <>
      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
      <circle cx="12" cy="12" r="3" />
    </>
  ),
  lapiz: <path d="M12 20h9M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4z" />,
  candado: (
    <>
      <rect x="3" y="11" width="18" height="11" rx="2" />
      <path d="M7 11V7a5 5 0 0 1 10 0v4" />
    </>
  ),
  escudoOk: <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10zM9 12l2 2 4-4" />,
  escudoPersona: (
    <>
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
      <circle cx="12" cy="10" r="2.5" />
      <path d="M8.5 16a3.5 3.5 0 0 1 7 0" />
    </>
  ),
  etiqueta: (
    <>
      <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z" />
      <path d="M7 7h.01" />
    </>
  ),
};

// Solo el cuadradito con el ícono
export function IconoCuadro({ icono, color }) {
  return (
    <span className={`icono-cuadro icono-${color}`} aria-hidden="true">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor"
           strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        {TRAZOS[icono] || TRAZOS.etiqueta}
      </svg>
    </span>
  );
}

// Celda de tabla: cuadradito + nombre en negrita + texto chico abajo si hace falta.
// Usa las mismas clases que PersonaCelda para que las dos se vean alineadas igual.
export default function IconoCelda({ icono, color, nombre, detalle }) {
  return (
    <div className="persona-celda">
      <IconoCuadro icono={icono} color={color} />
      <div>
        <div className="persona-celda-nombre">{nombre}</div>
        {detalle && <div className="persona-celda-detalle">{detalle}</div>}
      </div>
    </div>
  );
}
