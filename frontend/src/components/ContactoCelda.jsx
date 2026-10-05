import { formatearTelefono } from '../utils/formato';

// Celda "Contacto" de las tablas de personas (Empleados y Clientes): el mail arriba
// y el teléfono abajo, cada uno con su iconito, en lugar de una columna para cada uno.
// Así la tabla tiene menos columnas y cada fila queda de dos renglones, igual que la
// celda del nombre con el circulito.
export default function ContactoCelda({ email, telefono }) {
  return (
    <div className="contacto-celda">
      <span className="contacto-linea" title="Email">
        {/* Sobre de carta */}
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <rect x="2" y="4" width="20" height="16" rx="2" />
          <path d="m22 7-10 6L2 7" />
        </svg>
        <span className="contacto-email">{email || '—'}</span>
      </span>
      <span className="contacto-linea contacto-secundaria" title="Teléfono">
        {/* Teléfono */}
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z" />
        </svg>
        <span>{formatearTelefono(telefono) || '—'}</span>
      </span>
    </div>
  );
}
