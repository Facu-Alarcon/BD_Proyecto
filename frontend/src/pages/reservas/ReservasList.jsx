import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import { IconEditar, IconEliminar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';
import { PersonaCelda } from '../../components/Avatar';

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

// Pasa el texto a minúsculas y le saca los acentos, así "Ayelén" se encuentra buscando "ayelen"
function normalizar(texto) {
  return (texto || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '');
}

// Valores iniciales de los filtros (también se usan para el botón "Limpiar")
const FILTROS_VACIOS = { texto: '', desde: '', hasta: '', estado: '' };

export default function ReservasList() {
  const { puedeGestionar } = usePermiso('reservas');
  const [reservas, setReservas] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);
  const [filtros, setFiltros] = useState(FILTROS_VACIOS);

  function cargar() {
    setCargando(true);
    api
      .get('/reservas/')
      .then(({ data }) => setReservas(data))
      .catch(() => setError('No se pudieron cargar las reservas.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  // Cambia un solo filtro y deja los demás como estaban
  function actualizarFiltro(campo, valor) {
    setFiltros((f) => ({ ...f, [campo]: valor }));
  }

  // Si la fecha "desde" es posterior a "hasta" no tiene sentido filtrar, avisamos
  const rangoInvalido = filtros.desde && filtros.hasta && filtros.desde > filtros.hasta;

  const hayFiltros = Object.values(filtros).some(Boolean);

  // Acá se arma la lista que se muestra en la tabla aplicando todos los filtros juntos.
  // Las fechas vienen como 'AAAA-MM-DD', así que se pueden comparar directo como texto.
  const reservasFiltradas = useMemo(() => {
    if (rangoInvalido) return [];
    const buscado = normalizar(filtros.texto.trim());
    return reservas.filter((r) => {
      if (buscado && !normalizar(`${r.cliente_nombre} ${r.nombre_evento}`).includes(buscado)) return false;
      if (filtros.desde && r.fecha_evento < filtros.desde) return false;
      if (filtros.hasta && r.fecha_evento > filtros.hasta) return false;
      if (filtros.estado && r.estado_reserva !== filtros.estado) return false;
      return true;
    });
  }, [reservas, filtros, rangoInvalido]);

  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/reservas/${aEliminar.id_reserva}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar la reserva.');
    } finally {
      setEliminando(false);
    }
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

      {/* Barra de búsqueda y filtros */}
      <div className="card filtros">
        <div className="form-field filtros-buscar">
          <label htmlFor="filtro-texto">Buscar</label>
          <input
            id="filtro-texto"
            type="search"
            placeholder="Cliente o nombre del evento"
            value={filtros.texto}
            onChange={(e) => actualizarFiltro('texto', e.target.value)}
          />
        </div>

        <div className="form-field">
          <label htmlFor="filtro-desde">Desde</label>
          <input
            id="filtro-desde"
            type="date"
            value={filtros.desde}
            max={filtros.hasta || undefined}
            onChange={(e) => actualizarFiltro('desde', e.target.value)}
          />
        </div>

        <div className="form-field">
          <label htmlFor="filtro-hasta">Hasta</label>
          <input
            id="filtro-hasta"
            type="date"
            value={filtros.hasta}
            min={filtros.desde || undefined}
            onChange={(e) => actualizarFiltro('hasta', e.target.value)}
          />
        </div>

        <div className="form-field">
          <label htmlFor="filtro-estado">Estado</label>
          <select
            id="filtro-estado"
            value={filtros.estado}
            onChange={(e) => actualizarFiltro('estado', e.target.value)}
          >
            <option value="">Todos</option>
            <option value="PENDIENTE">Pendiente</option>
            <option value="CONFIRMADA">Confirmada</option>
            <option value="FINALIZADA">Finalizada</option>
            <option value="CANCELADA">Cancelada</option>
          </select>
        </div>

        <button
          type="button"
          className="btn btn-secondary"
          onClick={() => setFiltros(FILTROS_VACIOS)}
          disabled={!hayFiltros}
        >
          Limpiar
        </button>
      </div>

      {rangoInvalido && (
        <div className="alert alert-error">La fecha "Desde" no puede ser posterior a la fecha "Hasta".</div>
      )}

      {/* Contador para saber cuántas quedan después de filtrar */}
      {!cargando && hayFiltros && !rangoInvalido && (
        <p className="filtros-resultado">
          Mostrando {reservasFiltradas.length} de {reservas.length} reservas
        </p>
      )}

      <div className="card">
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
            {!cargando && reservas.length > 0 && reservasFiltradas.length === 0 && !rangoInvalido && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>No hay reservas que coincidan con la búsqueda.</td></tr>
            )}
            {reservasFiltradas.map((reserva) => (
              <tr key={reserva.id_reserva}>
                <td>
                  <PersonaCelda nombre={reserva.cliente_nombre} detalle={reserva.nombre_evento} />
                </td>
                <td>{formatearFecha(reserva.fecha_evento, reserva.hora_evento)}</td>
                <td>${Number(reserva.monto_total).toLocaleString('es-AR')}</td>
                <td><span className={`badge ${BADGE_BY_ESTADO[reserva.estado_reserva] || 'badge-gray'}`}>{reserva.estado_display}</span></td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/reservas/${reserva.id_reserva}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(reserva)} title="Eliminar"><IconEliminar /></button>
                    </div>
                  ) : (
                    <span className="form-hint">Solo lectura</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {aEliminar && (
        <ConfirmModal
          titulo="Eliminar reserva"
          mensaje={`¿Eliminar la reserva de "${aEliminar.cliente_nombre}"?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}
