import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../api/client';
import { colorEstadoEquipo } from '../utils/estadoEquipo';
import './Inicio.css';

const BADGE_BY_ESTADO = {
  PENDIENTE: 'badge-amber',
  CONFIRMADA: 'badge-green',
  FINALIZADA: 'badge-gray',
  CANCELADA: 'badge-red',
};

function formatearFecha(fecha, hora) {
  const [anio, mes, dia] = fecha.split('-');
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  const horaCorta = hora?.slice(0, 5) || '';
  return `${dia} ${meses[Number(mes) - 1]}, ${horaCorta}`;
}

export default function Inicio() {
  const [resumen, setResumen] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    api
      .get('/dashboard/resumen/')
      .then(({ data }) => setResumen(data))
      .catch(() => setError('No se pudo cargar el resumen.'));
  }, []);

  const eq = resumen?.equipos;
  const totalEquipos = eq?.total || 0;
  const pct = (n) => (totalEquipos ? Math.round((n / totalEquipos) * 100) : 0);

  function cantidadPorEstado(palabraClave) {
    const fila = eq?.por_estado?.find((e) => e.nombre_estadoeq.toLowerCase().includes(palabraClave));
    return fila?.cantidad ?? 0;
  }
  const disponibles = cantidadPorEstado('dispon');
  const enReparacion = cantidadPorEstado('repar');

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>BIENVENIDO</h1>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="stat-grid">
        <div className="card stat-card">
          <span className="stat-label">Reservas de hoy</span>
          <span className="stat-value">{resumen ? resumen.reservas_hoy : '—'}</span>
          <span className="stat-hint">
            {resumen ? `${resumen.reservas_hoy_confirmadas} confirmadas · ${resumen.reservas_hoy_pendientes} pendientes` : ''}
          </span>
        </div>
        <div className="card stat-card">
          <span className="stat-label">Equipos disponibles</span>
          <span className="stat-value">{eq ? `${disponibles} / ${eq.total}` : '—'}</span>
          <span className="stat-hint">sobre el total del inventario</span>
        </div>
        <div className="card stat-card">
          <span className="stat-label">Equipos en reparación</span>
          <span className="stat-value">{eq ? enReparacion : '—'}</span>
          <span className="stat-hint">fuera de servicio temporalmente</span>
        </div>
        <div className="card stat-card">
          <span className="stat-label">Usuarios del sistema</span>
          <span className="stat-value">{resumen ? resumen.usuarios_total : '—'}</span>
          <span className="stat-hint">{resumen ? `${resumen.perfiles_total} perfiles definidos` : ''}</span>
        </div>
      </div>

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
                <div className="avatar-badge">
                  {r.cliente_nombre.split(' ').filter(Boolean).slice(0, 2).map((p) => p[0].toUpperCase()).join('')}
                </div>
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
          <h2>Estado de equipos</h2>
          {eq && eq.por_estado.length === 0 && (
            <p className="form-hint">No hay equipos cargados todavía.</p>
          )}
          {eq?.por_estado.map((e) => (
            <div className="progress-row" key={e.id_estadoeq}>
              <div className="progress-head">
                <span>{e.nombre_estadoeq}</span>
                <span>{e.cantidad}/{eq.total}</span>
              </div>
              <div className="progress-track">
                <div
                  className={`progress-fill ${colorEstadoEquipo(e.nombre_estadoeq).bar}`}
                  style={{ width: `${pct(e.cantidad)}%` }}
                />
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
