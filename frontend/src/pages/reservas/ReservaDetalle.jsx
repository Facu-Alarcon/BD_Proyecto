import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import AnularReservaModal from '../../components/AnularReservaModal';
import {
  formatearFecha, formatearFechaHora, formatearPesos, formatearTelefono, horaCorta, numeroComprobante,
} from '../../utils/formato';

// Color de la etiqueta de estado (igual que en la lista)
const BADGE_POR_ESTADO = {
  PENDIENTE: 'badge-amber',
  CONFIRMADA: 'badge-green',
  FINALIZADA: 'badge-gray',
  ANULADA: 'badge-red',
};

// Pantalla "Ver reserva": muestra todo lo de una reserva en un solo lugar (cabecera,
// cliente, evento, servicios con precios, personal, pagos y, si está anulada, los datos
// de la anulación). Desde acá se puede ir al comprobante, editar o anular según el perfil.
export default function ReservaDetalle() {
  const { id } = useParams();
  const { puedeGestionar, tiene } = usePermiso('reservas');
  const [reserva, setReserva] = useState(null);
  const [error, setError] = useState('');
  const [anulando, setAnulando] = useState(false);

  function cargar() {
    api
      .get(`/reservas/${id}/`)
      .then(({ data }) => setReserva(data))
      .catch(() => setError('No se encontró la reserva.'));
  }

  useEffect(cargar, [id]);

  if (error) return <div className="alert alert-error">{error}</div>;
  if (!reserva) return <p>Cargando...</p>;

  const anulada = reserva.estado_reserva === 'ANULADA';
  const editable = puedeGestionar && !anulada;
  const anulable = tiene('anular_reservas') && ['PENDIENTE', 'CONFIRMADA'].includes(reserva.estado_reserva);
  const { pagos, total_pagado: totalPagado, saldo } = reserva.pagos_detalle;

  return (
    <div>
      {/* Encabezado: número de comprobante, estado y acciones */}
      <div className="page-header page-header-con-ruta">
        <div>
          <h1>
            Reserva N° {numeroComprobante(reserva.id_reserva)}{' '}
            <span className={`badge ${BADGE_POR_ESTADO[reserva.estado_reserva] || 'badge-gray'}`}>{reserva.estado_display}</span>
          </h1>
          <nav className="ruta" aria-label="Ruta">
            <Link to="/reservas">Reservas</Link> / <strong>N° {numeroComprobante(reserva.id_reserva)}</strong>
          </nav>
        </div>
        <div className="detalle-acciones">
          <Link to={`/reservas/${reserva.id_reserva}/comprobante`} className="btn btn-primary">Comprobante</Link>
          {editable && <Link to={`/reservas/${reserva.id_reserva}/editar`} className="btn btn-outline">Editar</Link>}
          {anulable && <button type="button" className="btn btn-danger" onClick={() => setAnulando(true)}>Anular</button>}
        </div>
      </div>

      {/* Si está anulada, lo primero que se ve es por qué, cuándo y quién */}
      {anulada && (
        <div className="alert alert-error detalle-anulacion">
          <strong>Reserva anulada</strong> el {formatearFechaHora(reserva.fecha_anulacion)}
          {reserva.usuario_anulacion && ` por ${reserva.usuario_anulacion}`}.
          <br />Motivo: {reserva.motivo_anulacion || '—'}
        </div>
      )}

      <div className="detalle-grilla">
        {/* Datos del registro (automáticos) */}
        <section className="card detalle-card">
          <h2>Registro</h2>
          <dl className="detalle-datos">
            <dt>N° de comprobante</dt><dd>{numeroComprobante(reserva.id_reserva)}</dd>
            <dt>Fecha de registro</dt><dd>{reserva.fecha_registro ? formatearFechaHora(reserva.fecha_registro) : 'Sin dato (reserva anterior)'}</dd>
            <dt>Registrada por</dt><dd>{reserva.usuario_registro || 'Sin dato (reserva anterior)'}</dd>
            <dt>Estado</dt><dd>{reserva.estado_display}</dd>
          </dl>
        </section>

        {/* Cliente */}
        <section className="card detalle-card">
          <h2>Cliente</h2>
          <dl className="detalle-datos">
            <dt>Nombre</dt><dd>{reserva.cliente_detalle.nombre}</dd>
            <dt>Teléfono</dt><dd>{formatearTelefono(reserva.cliente_detalle.telefono)}</dd>
            <dt>Email</dt><dd>{reserva.cliente_detalle.email}</dd>
            <dt>Domicilio</dt><dd>{reserva.cliente_detalle.domicilio}</dd>
          </dl>
        </section>

        {/* Evento */}
        <section className="card detalle-card">
          <h2>Evento</h2>
          <dl className="detalle-datos">
            <dt>Evento</dt><dd>{reserva.nombre_evento || '—'}</dd>
            <dt>Fecha</dt><dd>{formatearFecha(reserva.fecha_evento)}</dd>
            <dt>Hora</dt><dd>{horaCorta(reserva.hora_evento)}</dd>
            <dt>Duración</dt><dd>{horaCorta(reserva.duracion_evento)} hs</dd>
            <dt>Dirección</dt><dd>{reserva.direccion_evento}</dd>
          </dl>
        </section>

        {/* Personal asignado */}
        <section className="card detalle-card">
          <h2>Personal asignado</h2>
          {reserva.empleados_detalle.length === 0 ? (
            <p className="form-hint">Sin personal asignado.</p>
          ) : (
            <ul className="detalle-lista">
              {reserva.empleados_detalle.map((e) => (
                <li key={e.id_empleado}>{e.nombre_emp} {e.apellido_emp}</li>
              ))}
            </ul>
          )}
        </section>
      </div>

      {/* Servicios (el detalle de la reserva) con el precio guardado al reservar */}
      <section className="card detalle-card">
        <h2>Servicios</h2>
        <table className="data-table">
          <thead>
            <tr><th>Servicio</th><th className="numero">Precio</th></tr>
          </thead>
          <tbody>
            {reserva.servicios_detalle.map((s) => (
              <tr key={s.id_servicio}>
                <td>{s.tipo_servicio}</td>
                <td className="numero">{formatearPesos(s.precio_servicio)}</td>
              </tr>
            ))}
            <tr className="fila-total">
              <td>Total</td>
              <td className="numero">{formatearPesos(reserva.monto_total)}</td>
            </tr>
          </tbody>
        </table>
      </section>

      {/* Pagos de la reserva y cuánto falta */}
      <section className="card detalle-card">
        <h2>Pagos</h2>
        {pagos.length === 0 ? (
          <p className="form-hint">Todavía no hay pagos registrados.</p>
        ) : (
          <table className="data-table">
            <thead>
              <tr><th>Pago</th><th>Método</th><th className="numero">Monto</th></tr>
            </thead>
            <tbody>
              {pagos.map((p) => (
                <tr key={p.id_pago}>
                  <td>N° {p.id_pago}</td>
                  <td>{p.metodos.join(', ') || '—'}</td>
                  <td className="numero">{formatearPesos(p.monto)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <div className="detalle-resumen">
          <span>Pagado: <strong>{formatearPesos(totalPagado)}</strong></span>
          <span>Saldo pendiente: <strong>{formatearPesos(saldo)}</strong></span>
        </div>
      </section>

      {anulando && (
        <AnularReservaModal
          reserva={reserva}
          onCancelar={() => setAnulando(false)}
          onAnulada={() => {
            setAnulando(false);
            cargar();
          }}
        />
      )}
    </div>
  );
}
