import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import BarraFiltros, { FilaSinResultados } from '../../components/BarraFiltros';
import { useFiltros } from '../../hooks/useFiltros';
import Paginacion from '../../components/Paginacion';
import { usePaginacion } from '../../hooks/usePaginacion';
import { IconAnular, IconEditar, IconVer } from '../../components/icons';
import AnularReservaModal from '../../components/AnularReservaModal';
import { PersonaCelda } from '../../components/Avatar';

const BADGE_BY_ESTADO = {
  PENDIENTE: 'badge-amber',
  CONFIRMADA: 'badge-green',
  FINALIZADA: 'badge-gray',
  ANULADA: 'badge-red',
};

function formatearFecha(fecha, hora) {
  const [anio, mes, dia] = fecha.split('-');
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  const horaCorta = hora?.slice(0, 5) || '';
  return `${dia} ${meses[Number(mes) - 1]}, ${horaCorta}`;
}

export default function ReservasList() {
  const { puedeGestionar, tiene } = usePermiso('reservas');
  // Anular es un permiso aparte: un perfil puede registrar reservas pero no anularlas
  const puedeAnular = tiene('anular_reservas');
  const [reservas, setReservas] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aAnular, setAAnular] = useState(null); // reserva que se está por anular

  function cargar() {
    setCargando(true);
    api
      .get('/reservas/')
      .then(({ data }) => setReservas(data))
      .catch(() => setError('No se pudieron cargar las reservas.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  // Filtros de esta pantalla (ver hooks/useFiltros.js)
  const configFiltros = [
    { tipo: 'texto', id: 'texto', placeholder: 'Cliente o nombre del evento', campos: (r) => [r.cliente_nombre, r.nombre_evento] },
    { tipo: 'rango', id: 'fecha', label: 'Fecha', input: 'date', valor: (r) => r.fecha_evento },
    {
      tipo: 'select', id: 'estado', label: 'Estado', valor: (r) => r.estado_reserva,
      opciones: [
        { value: 'PENDIENTE', label: 'Pendiente' },
        { value: 'CONFIRMADA', label: 'Confirmada' },
        { value: 'FINALIZADA', label: 'Finalizada' },
        { value: 'ANULADA', label: 'Anulada' },
      ],
    },
  ];
  const filtros = useFiltros(reservas, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  // Después de anular se cierra la ventana y se recarga la lista (la reserva sigue, ahora Anulada)
  function terminarAnulacion() {
    setAAnular(null);
    cargar();
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Reservas</h1>
        </div>
        {puedeGestionar && <Link to="/reservas/nueva" className="btn btn-primary">+ Nueva Reserva</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={reservas.length} cargando={cargando} nombreItems="reservas" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
        <table className="data-table">
          <thead>
            <tr>
              <th>Cliente</th>
              <th>Fecha</th>
              <th>Monto</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && reservas.length === 0 && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>No hay reservas cargadas.</td></tr>
            )}
            <FilaSinResultados filtros={filtros} total={reservas.length} cargando={cargando} columnas={5} nombreItems="reservas" />
            {paginacion.visibles.map((reserva) => (
              <tr key={reserva.id_reserva}>
                <td>
                  <PersonaCelda nombre={reserva.cliente_nombre} detalle={reserva.nombre_evento} />
                </td>
                <td>{formatearFecha(reserva.fecha_evento, reserva.hora_evento)}</td>
                <td>${Number(reserva.monto_total).toLocaleString('es-AR')}</td>
                <td><span className={`badge ${BADGE_BY_ESTADO[reserva.estado_reserva] || 'badge-gray'}`}>{reserva.estado_display}</span></td>
                <td>
                  {/* Ver: todos los que pueden ver reservas (detalle y comprobante).
                      Editar: con permiso de gestionar y si no está anulada.
                      Anular: con el permiso "Anular Reservas" y solo si está Pendiente o Confirmada */}
                  {(() => {
                    const editable = puedeGestionar && reserva.estado_reserva !== 'ANULADA';
                    const anulable = puedeAnular && ['PENDIENTE', 'CONFIRMADA'].includes(reserva.estado_reserva);
                    return (
                      <div className="actions-cell">
                        <Link to={`/reservas/${reserva.id_reserva}`} className="btn btn-secondary btn-sm" title="Ver detalle y comprobante"><IconVer /></Link>
                        {editable && (
                          <Link to={`/reservas/${reserva.id_reserva}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                        )}
                        {anulable && (
                          <button type="button" className="btn btn-danger btn-sm" onClick={() => setAAnular(reserva)} title="Anular"><IconAnular /></button>
                        )}
                      </div>
                    );
                  })()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <Paginacion paginacion={paginacion} />
      </div>

      {aAnular && (
        <AnularReservaModal reserva={aAnular} onCancelar={() => setAAnular(null)} onAnulada={terminarAnulacion} />
      )}
    </div>
  );
}
