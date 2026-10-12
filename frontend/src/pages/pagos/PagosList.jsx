import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import BarraFiltros, { FilaSinResultados } from '../../components/BarraFiltros';
import { useFiltros, opcionesDe } from '../../hooks/useFiltros';
import Paginacion from '../../components/Paginacion';
import { usePaginacion } from '../../hooks/usePaginacion';
import { IconAnular, IconEditar } from '../../components/icons';
import AnularPagoModal from '../../components/AnularPagoModal';
import { PersonaCelda } from '../../components/Avatar';

// Lista de Pagos: cada pago con su reserva, monto, saldo pendiente y métodos usados.
// Los pagos no se eliminan: se anulan con motivo, y quedan en la lista marcados como Anulado.
export default function PagosList() {
  // Qué puede hacer el usuario en este módulo según su perfil (si no puede gestionar, solo ve la tabla)
  const { puedeGestionar } = usePermiso('pagos');
  const [pagos, setPagos] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  // El pago que se está por anular. Cuando tiene algo, se abre la ventana que pide el motivo
  const [aAnular, setAAnular] = useState(null);

  // Trae todos los registros del backend y los guarda para la tabla
  function cargar() {
    setCargando(true);
    api
      .get('/pagos/')
      .then(({ data }) => setPagos(data))
      .catch(() => setError('No se pudieron cargar los pagos.'))
      .finally(() => setCargando(false));
  }

  // Se cargan una sola vez, al abrir la pantalla
  useEffect(cargar, []);

  // Filtros de esta pantalla (ver hooks/useFiltros.js)
  const configFiltros = [
    { tipo: 'texto', id: 'texto', placeholder: 'Cliente o nombre del evento', campos: (p) => [p.cliente_nombre, p.evento_nombre] },
    {
      tipo: 'select', id: 'metodo', label: 'Método de pago',
      valor: (p) => p.metodos_pago_detalle.map((m) => m.metodo_pago),
      opciones: opcionesDe(pagos, (p) => p.metodos_pago_detalle.map((m) => m.metodo_pago)),
    },
    {
      tipo: 'select', id: 'saldo', label: 'Saldo', valor: (p) => (p.saldo_pendiente > 0 ? 'pendiente' : 'saldado'),
      opciones: [{ value: 'pendiente', label: 'Con saldo pendiente' }, { value: 'saldado', label: 'Saldados' }],
    },
    { tipo: 'rango', id: 'monto', label: 'Monto', input: 'number', valor: (p) => p.monto },
    // Filtro para ver solo los pagos vigentes o solo los anulados
    {
      tipo: 'select', id: 'estado', label: 'Estado', valor: (p) => (p.anulado ? 'anulado' : 'vigente'),
      opciones: [{ value: 'vigente', label: 'Vigentes' }, { value: 'anulado', label: 'Anulados' }],
    },
  ];
  const filtros = useFiltros(pagos, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Pagos</h1>
        </div>
        {puedeGestionar && <Link to="/pagos/nuevo" className="btn btn-primary">+ Nuevo Pago</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={pagos.length} cargando={cargando} nombreItems="pagos" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
        {/* Tabla con las filas de la página actual (paginacion.visibles) */}
        <table className="data-table">
          <thead>
            <tr>
              <th>Reserva</th>
              <th>Monto</th>
              <th>Saldo pendiente</th>
              <th>Método(s) de pago</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={6} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && pagos.length === 0 && (
              <tr><td colSpan={6} style={{ textAlign: 'center' }}>No hay pagos registrados.</td></tr>
            )}
            <FilaSinResultados filtros={filtros} total={pagos.length} cargando={cargando} columnas={6} nombreItems="pagos" />
            {paginacion.visibles.map((pago) => (
              <tr key={pago.id_pago}>
                <td><PersonaCelda nombre={pago.cliente_nombre} detalle={pago.evento_nombre} /></td>
                <td>${Number(pago.monto).toLocaleString('es-AR')}</td>
                <td>${Number(pago.saldo_pendiente).toLocaleString('es-AR')}</td>
                <td>
                  {pago.metodos_pago_detalle.length === 0
                    ? <span className="form-hint">Sin especificar</span>
                    : pago.metodos_pago_detalle.map((m) => m.metodo_pago).join(', ')}
                </td>
                {/* Cartelito verde si el pago vale, rojo si está anulado. Dejando el mouse
                    arriba de "Anulado" se ve el motivo y quién lo anuló */}
                <td>
                  {pago.anulado
                    ? <span className="badge badge-red" title={`${pago.motivo_anulacion}${pago.usuario_anulacion ? ` — ${pago.usuario_anulacion}` : ''}`}>Anulado</span>
                    : <span className="badge badge-green">Vigente</span>}
                </td>
                <td>
                  {/* Un pago anulado ya no tiene botones: no se puede editar ni anular de nuevo */}
                  {pago.anulado ? (
                    <span className="form-hint">Sin acciones</span>
                  ) : puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/pagos/${pago.id_pago}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAAnular(pago)} title="Anular"><IconAnular /></button>
                    </div>
                  ) : (
                    <span className="form-hint">Solo lectura</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <Paginacion paginacion={paginacion} />
      </div>

      {/* Ventana que pide el motivo (aparece al tocar el botón Anular de alguna fila).
          Cuando termina, se cierra y se vuelve a cargar la lista */}
      {aAnular && (
        <AnularPagoModal
          pago={aAnular}
          onCancelar={() => setAAnular(null)}
          onAnulado={() => { setAAnular(null); cargar(); }}
        />
      )}
    </div>
  );
}