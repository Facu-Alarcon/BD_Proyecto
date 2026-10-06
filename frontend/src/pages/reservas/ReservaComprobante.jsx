import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import api from '../../api/client';
import logo from '../../assets/img/logonuevo.png';
import {
  formatearFecha, formatearFechaHora, formatearPesos, formatearTelefono, horaCorta, numeroComprobante,
} from '../../utils/formato';
import './ReservaComprobante.css';

// Comprobante de una reserva, listo para imprimir o guardar en PDF.
// El botón "Imprimir / Guardar PDF" abre la ventana de impresión del navegador; ahí se
// elige la impresora o "Guardar como PDF". Al imprimir se esconden el menú, la barra de
// arriba y los botones (ver ReservaComprobante.css), así sale solo la hoja.
export default function ReservaComprobante() {
  const { id } = useParams();
  const [reserva, setReserva] = useState(null);
  const [error, setError] = useState('');
  // Fecha y hora en que se emite el comprobante (se fija al abrir la pantalla)
  const [emitido] = useState(() => new Date().toISOString());

  useEffect(() => {
    api
      .get(`/reservas/${id}/`)
      .then(({ data }) => setReserva(data))
      .catch(() => setError('No se encontró la reserva.'));
  }, [id]);

  // El título de la pestaña es el nombre que propone el navegador al guardar el PDF
  // (ej: "Comprobante-Reserva-000012.pdf"). Al salir de la pantalla se vuelve a dejar el de siempre.
  useEffect(() => {
    if (!reserva) return undefined;
    const tituloAnterior = document.title;
    document.title = `Comprobante-Reserva-${numeroComprobante(reserva.id_reserva)}`;
    return () => {
      document.title = tituloAnterior;
    };
  }, [reserva]);

  if (error) return <div className="alert alert-error">{error}</div>;
  if (!reserva) return <p>Cargando...</p>;

  const anulada = reserva.estado_reserva === 'ANULADA';
  const { pagos, total_pagado: totalPagado, saldo } = reserva.pagos_detalle;

  return (
    <div className="comprobante-pantalla">
      {/* Botones: no salen en la impresión */}
      <div className="comprobante-botones no-imprimir">
        <Link to={`/reservas/${reserva.id_reserva}`} className="btn btn-outline">Volver a la reserva</Link>
        <button type="button" className="btn btn-primary" onClick={() => window.print()}>
          Imprimir / Guardar PDF
        </button>
      </div>

      {/* La hoja del comprobante */}
      <article className={`comprobante${anulada ? ' comprobante-anulado' : ''}`}>
        {/* Sello de ANULADA cruzando la hoja, para que no se pueda usar como válido */}
        {anulada && <div className="comprobante-sello" aria-hidden="true">ANULADA</div>}

        <header className="comprobante-encabezado">
          <img src={logo} alt="Infinito Sonido e Iluminación" className="comprobante-logo" />
          <div className="comprobante-numero">
            <span>Comprobante de reserva</span>
            <strong>N° {numeroComprobante(reserva.id_reserva)}</strong>
            <span>Emitido: {formatearFechaHora(emitido)}</span>
          </div>
        </header>

        {/* Datos del registro y del cliente, en dos columnas */}
        <section className="comprobante-dos-columnas">
          <div>
            <h3>Cliente</h3>
            <p><strong>{reserva.cliente_detalle.nombre}</strong></p>
            <p>Tel.: {formatearTelefono(reserva.cliente_detalle.telefono)}</p>
            <p>{reserva.cliente_detalle.email}</p>
            <p>{reserva.cliente_detalle.domicilio}</p>
          </div>
          <div>
            <h3>Reserva</h3>
            <p>Estado: <strong>{reserva.estado_display}</strong></p>
            <p>Registrada: {reserva.fecha_registro ? formatearFechaHora(reserva.fecha_registro) : '—'}</p>
            <p>Atendió: {reserva.usuario_registro || '—'}</p>
          </div>
        </section>

        {/* Datos del evento */}
        <section className="comprobante-evento">
          <h3>Evento</h3>
          <p>
            <strong>{reserva.nombre_evento || 'Evento'}</strong> · {formatearFecha(reserva.fecha_evento)} a las{' '}
            {horaCorta(reserva.hora_evento)} hs · Duración: {horaCorta(reserva.duracion_evento)} hs
          </p>
          <p>Lugar: {reserva.direccion_evento}</p>
        </section>

        {/* Detalle de servicios con su precio y el total */}
        <table className="comprobante-tabla">
          <thead>
            <tr><th>Servicio</th><th className="numero">Importe</th></tr>
          </thead>
          <tbody>
            {reserva.servicios_detalle.map((s) => (
              <tr key={s.id_servicio}>
                <td>{s.tipo_servicio}</td>
                <td className="numero">{formatearPesos(s.precio_servicio)}</td>
              </tr>
            ))}
          </tbody>
          <tfoot>
            <tr><td>Total</td><td className="numero">{formatearPesos(reserva.monto_total)}</td></tr>
            <tr className="comprobante-secundaria"><td>Pagado{pagos.length ? ` (${pagos.length} pago${pagos.length > 1 ? 's' : ''})` : ''}</td><td className="numero">{formatearPesos(totalPagado)}</td></tr>
            <tr className="comprobante-secundaria"><td>Saldo pendiente</td><td className="numero">{formatearPesos(saldo)}</td></tr>
          </tfoot>
        </table>

        {/* Si está anulada, el motivo queda impreso */}
        {anulada && (
          <section className="comprobante-motivo">
            <h3>Reserva anulada</h3>
            <p>
              El {formatearFechaHora(reserva.fecha_anulacion)}
              {reserva.usuario_anulacion && ` por ${reserva.usuario_anulacion}`}. Motivo: {reserva.motivo_anulacion || '—'}
            </p>
          </section>
        )}

        <footer className="comprobante-pie">
          <p>Infinito Sonido e Iluminación · Salta, Argentina</p>
          <p>Este comprobante no es una factura. Conservalo como constancia de tu reserva.</p>
        </footer>
      </article>
    </div>
  );
}
