import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import BarraFiltros, { FilaSinResultados } from '../../components/BarraFiltros';
import Paginacion from '../../components/Paginacion';
import { useFiltros, opcionesDe } from '../../hooks/useFiltros';
import { usePaginacion } from '../../hooks/usePaginacion';
import { usePermiso } from '../../hooks/usePermiso';

// Color de la etiqueta según el tipo de aviso: rojo lo de plata, ámbar lo que hay que confirmar
const BADGE_POR_TIPO = {
  SALDO_PENDIENTE: 'badge-red',
  SIN_CONFIRMAR: 'badge-amber',
  MONTO_INUSUAL: 'badge-gray',
};

// La API manda la fecha completa (con hora y zona); acá se muestra como 08/11/2026 17:29
function formatearFechaHora(iso) {
  const d = new Date(iso);
  const dosDigitos = (n) => String(n).padStart(2, '0');
  return `${dosDigitos(d.getDate())}/${dosDigitos(d.getMonth() + 1)}/${d.getFullYear()} ${dosDigitos(d.getHours())}:${dosDigitos(d.getMinutes())}`;
}

// Fecha local 'AAAA-MM-DD' de un aviso, para el filtro de fechas
function diaLocal(iso) {
  const d = new Date(iso);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

// Le avisa a la campana de la barra de arriba que cambió la cantidad de avisos sin leer
function avisarCampana() {
  window.dispatchEvent(new Event('notificaciones-actualizadas'));
}

// Pantalla "Notificaciones": la bandeja con los avisos que generan las reglas de alerta
// (saldo pendiente, reserva sin confirmar, monto inusual). Cada usuario ve los avisos
// dirigidos a su perfil y los puede marcar como leídos.
export default function Notificaciones() {
  const [avisos, setAvisos] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [mensaje, setMensaje] = useState('');
  const [revisando, setRevisando] = useState(false);
  // El botón "Revisar alertas ahora" solo lo ve quien gestiona la configuración de las alertas
  const { puedeGestionar: puedeRevisar } = usePermiso('configuracion');

  function cargar() {
    setCargando(true);
    api
      .get('/notificaciones/')
      .then(({ data }) => setAvisos(data))
      .catch(() => setError('No se pudieron cargar las notificaciones.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  // Marca un aviso como leído y lo actualiza en la lista sin volver a pedir todo
  function marcarLeida(aviso) {
    api
      .post(`/notificaciones/${aviso.id_notificacion}/leer/`)
      .then(({ data }) => {
        setAvisos((anteriores) => anteriores.map((a) => (a.id_notificacion === data.id_notificacion ? data : a)));
        avisarCampana();
      })
      .catch(() => setError('No se pudo marcar el aviso como leído.'));
  }

  function marcarTodas() {
    api
      .post('/notificaciones/leer-todas/')
      .then(() => {
        cargar();
        avisarCampana();
      })
      .catch(() => setError('No se pudieron marcar los avisos como leídos.'));
  }

  // Corre en el momento el mismo control que se hace una vez por día
  function revisarAhora() {
    setRevisando(true);
    setMensaje('');
    api
      .post('/notificaciones/revisar-ahora/')
      .then(({ data }) => {
        setMensaje(data.nuevos ? `Se generaron ${data.nuevos} aviso(s) nuevo(s).` : 'No hay avisos nuevos: todo está al día.');
        cargar();
        avisarCampana();
      })
      .catch(() => setError('No se pudieron revisar las alertas.'))
      .finally(() => setRevisando(false));
  }

  const sinLeer = avisos.filter((a) => !a.leida).length;

  // Filtros: texto del aviso, tipo, si está leído o no, y rango de fechas
  const configFiltros = [
    { tipo: 'texto', id: 'texto', placeholder: 'Cliente, reserva o texto del aviso', campos: (a) => [a.mensaje, a.id_objeto] },
    { tipo: 'select', id: 'tipo', label: 'Tipo', valor: (a) => a.tipo_display, opciones: opcionesDe(avisos, (a) => a.tipo_display) },
    {
      tipo: 'select', id: 'estado', label: 'Estado', valor: (a) => (a.leida ? 'Leída' : 'Sin leer'),
      opciones: [{ value: 'Sin leer', label: 'Sin leer' }, { value: 'Leída', label: 'Leída' }],
    },
    { tipo: 'rango', id: 'fecha', label: 'Fecha', input: 'date', valor: (a) => diaLocal(a.fecha) },
  ];
  const filtros = useFiltros(avisos, configFiltros);
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Notificaciones</h1>
          <p>Avisos automáticos del sistema: saldos pendientes, reservas sin confirmar y montos fuera de lo común.</p>
        </div>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {puedeRevisar && (
            <button type="button" className="btn btn-secondary" onClick={revisarAhora} disabled={revisando}>
              {revisando ? 'Revisando...' : 'Revisar alertas ahora'}
            </button>
          )}
          <button type="button" className="btn btn-primary" onClick={marcarTodas} disabled={!sinLeer}>
            Marcar todas como leídas
          </button>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}
      {mensaje && <div className="alert alert-success">{mensaje}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={avisos.length} cargando={cargando} nombreItems="avisos" />

      <div className="card">
        <Paginacion paginacion={paginacion} posicion="arriba" />
        <table className="data-table">
          <thead>
            <tr>
              <th>Fecha</th>
              <th>Tipo</th>
              <th>Aviso</th>
              <th>Reserva</th>
              <th>Estado</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && avisos.length === 0 && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>No hay notificaciones.</td></tr>
            )}
            <FilaSinResultados filtros={filtros} total={avisos.length} cargando={cargando} columnas={5} nombreItems="avisos" />
            {paginacion.visibles.map((a) => (
              // Los que no se leyeron van en negrita, para que se distingan a simple vista
              <tr key={a.id_notificacion} style={a.leida ? undefined : { fontWeight: 600 }}>
                <td style={{ whiteSpace: 'nowrap', fontVariantNumeric: 'tabular-nums' }}>{formatearFechaHora(a.fecha)}</td>
                <td><span className={`badge ${BADGE_POR_TIPO[a.tipo] || 'badge-gray'}`}>{a.tipo_display}</span></td>
                <td>{a.mensaje}</td>
                <td><Link to={`/reservas/${a.id_objeto}`}>N° {a.id_objeto}</Link></td>
                <td style={{ whiteSpace: 'nowrap' }}>
                  {a.leida ? (
                    <span className="form-hint" title={`Leída el ${formatearFechaHora(a.fecha_lectura)}`}>Leída</span>
                  ) : (
                    <button type="button" className="btn btn-secondary btn-sm" onClick={() => marcarLeida(a)}>
                      Marcar como leída
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <Paginacion paginacion={paginacion} />
      </div>
    </div>
  );
}
