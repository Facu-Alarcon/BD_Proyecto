import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../api/client';
import './Inicio.css';
import Avatar from '../components/Avatar';

// Color de la etiqueta según el estado de la reserva
const BADGE_BY_ESTADO = {
  PENDIENTE: 'badge-amber',
  CONFIRMADA: 'badge-green',
  FINALIZADA: 'badge-gray',
  ANULADA: 'badge-red',
};

// Fecha corta para la lista de próximas reservas: "2026-10-18" + "21:00:00" -> "18 oct, 21:00"
function formatearFecha(fecha, hora) {
  const [anio, mes, dia] = fecha.split('-');
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  const horaCorta = hora?.slice(0, 5) || '';
  return `${dia} ${meses[Number(mes) - 1]}, ${horaCorta}`;
}

// Pantalla de Inicio: tarjetas con números del día y del inventario, las próximas reservas
// y el estado de los equipos. Todo sale de un solo pedido a /dashboard/resumen/.
export default function Inicio() {
  const [resumen, setResumen] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    api
      .get('/dashboard/resumen/')
      .then(({ data }) => setResumen(data))
      .catch(() => setError('No se pudo cargar el resumen.'));
  }, []);

  // Equipos de hoy (los calcula el backend con las reservas del día, ver disponibilidad.py)
  const hoyEq = resumen?.equipos_hoy;
  const pctHoy = (n) => (hoyEq?.total ? Math.round((n / hoyEq.total) * 100) : 0);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>BIENVENIDO</h1>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      {/* Tarjetas con los números principales ("—" mientras se cargan) */}
      <div className="stat-grid">
        <div className="card stat-card">
          <span className="stat-label">Reservas de hoy</span>
          <span className="stat-value">{resumen ? resumen.reservas_hoy : '—'}</span>
          <span className="stat-hint">
            {resumen ? `${resumen.reservas_hoy_confirmadas} confirmadas · ${resumen.reservas_hoy_pendientes} pendientes` : ''}
          </span>
        </div>
        <div className="card stat-card">
          {/* Equipos libres hoy: se descuentan los que usan las reservas de hoy y los que están en reparación */}
          <span className="stat-label">Equipos disponibles hoy</span>
          <span className="stat-value">{hoyEq ? `${hoyEq.libres} / ${hoyEq.total}` : '—'}</span>
          <span className="stat-hint">{hoyEq ? `${hoyEq.ocupadas} ${hoyEq.ocupadas === 1 ? 'equipo en uso' : 'equipos en uso'} por reservas de hoy` : ''}</span>
        </div>
        <div className="card stat-card">
          <span className="stat-label">Equipos en reparación</span>
          <span className="stat-value">{hoyEq ? hoyEq.en_reparacion : '—'}</span>
          <span className="stat-hint">fuera de servicio temporalmente</span>
        </div>
        <div className="card stat-card">
          <span className="stat-label">Usuarios del sistema</span>
          <span className="stat-value">{resumen ? resumen.usuarios_total : '—'}</span>
          <span className="stat-hint">{resumen ? `${resumen.perfiles_total} perfiles definidos` : ''}</span>
        </div>
      </div>

      {/* Abajo: próximas reservas a la izquierda y estado de los equipos a la derecha */}
      <div className="inicio-grid">
        <div className="card inicio-panel">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
            <h2 style={{ margin: 0 }}>Próximas reservas</h2>
            <Link to="/reservas" style={{ fontSize: 13, fontWeight: 600, color: 'var(--navy-accent)' }}>Ver todas</Link>
          </div>
          {resumen && resumen.proximas_reservas.length === 0 && (
            <p className="form-hint">No hay reservas próximas cargadas.</p>
          )}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            {resumen?.proximas_reservas.map((r) => (
              <div key={r.id_reserva} className="reserva-row">
                <Avatar nombre={r.cliente_nombre} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 600 }}>{r.cliente_nombre}</div>
                  {r.nombre_evento && <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{r.nombre_evento}</div>}
                </div>
                <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>{formatearFecha(r.fecha_evento, r.hora_evento)}</div>
                <span className={`badge ${BADGE_BY_ESTADO[r.estado_reserva] || 'badge-gray'}`}>{r.estado_display}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="card inicio-panel">
          {/* Estado de los equipos hoy: libres, en uso por reservas de hoy y en reparación.
              Un equipo ocupado por una reserva no figura como disponible. */}
          <h2>Estado de equipos hoy</h2>
          {hoyEq && hoyEq.total > 0 && [
            { nombre: 'Disponibles', cantidad: hoyEq.libres, color: 'fill-green' },
            { nombre: 'En uso por reservas', cantidad: hoyEq.ocupadas, color: 'fill-blue' },
            { nombre: 'En reparación', cantidad: hoyEq.en_reparacion, color: 'fill-red' },
          ].map((fila) => (
            <div className="progress-row" key={fila.nombre}>
              <div className="progress-head">
                <span>{fila.nombre}</span>
                <span>{fila.cantidad}/{hoyEq.total}</span>
              </div>
              <div className="progress-track">
                <div className={`progress-fill ${fila.color}`} style={{ width: `${pctHoy(fila.cantidad)}%` }} />
              </div>
            </div>
          ))}
          {/* Nombre y cantidad de lo que se está usando hoy (ej: "4 Bafle, 2 Par LED") */}
          {hoyEq?.en_uso.length > 0 && (
            <p className="form-hint">En uso hoy: {hoyEq.en_uso.map((e) => `${e.cantidad} ${e.nombre_equipo}`).join(', ')}.</p>
          )}
          {hoyEq?.agotados.length > 0 && (
            <p className="form-hint">Sin equipos libres hoy: {hoyEq.agotados.join(', ')}.</p>
          )}
          {hoyEq && hoyEq.total === 0 && (
            <p className="form-hint">No hay equipos cargados todavía.</p>
          )}
        </div>
      </div>
    </div>
  );
}
