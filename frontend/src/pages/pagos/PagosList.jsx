import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import { IconEditar, IconEliminar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';
import { PersonaCelda } from '../../components/Avatar';

export default function PagosList() {
  const { puedeGestionar } = usePermiso('pagos');
  const [pagos, setPagos] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  function cargar() {
    setCargando(true);
    api
      .get('/pagos/')
      .then(({ data }) => setPagos(data))
      .catch(() => setError('No se pudieron cargar los pagos.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/pagos/${aEliminar.id_pago}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el pago.');
    } finally {
      setEliminando(false);
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Pagos</h1>
        </div>
        {puedeGestionar && <Link to="/pagos/nuevo" className="btn btn-primary">+ Nuevo Pago</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Reserva</th>
              <th>Monto</th>
              <th>Saldo pendiente</th>
              <th>Método(s) de pago</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && pagos.length === 0 && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>No hay pagos registrados.</td></tr>
            )}
            {pagos.map((pago) => (
              <tr key={pago.id_pago}>
                <td><PersonaCelda nombre={pago.cliente_nombre} detalle={pago.evento_nombre} /></td>
                <td>${Number(pago.monto).toLocaleString('es-AR')}</td>
                <td>${Number(pago.saldo_pendiente).toLocaleString('es-AR')}</td>
                <td>
                  {pago.metodos_pago_detalle.length === 0
                    ? <span className="form-hint">Sin especificar</span>
                    : pago.metodos_pago_detalle.map((m) => m.metodo_pago).join(', ')}
                </td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/pagos/${pago.id_pago}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(pago)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar pago"
          mensaje={`¿Eliminar el pago de $${Number(aEliminar.monto).toLocaleString('es-AR')} de ${aEliminar.cliente_nombre}?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}