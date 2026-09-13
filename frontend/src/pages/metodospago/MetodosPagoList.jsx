import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import { IconEditar, IconEliminar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';

export default function MetodosPagoList() {
  const { puedeGestionar } = usePermiso('metodos_pago');
  const [metodos, setMetodos] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  function cargar() {
    setCargando(true);
    api
      .get('/metodos-pago/')
      .then(({ data }) => setMetodos(data))
      .catch(() => setError('No se pudieron cargar los métodos de pago.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/metodos-pago/${aEliminar.id_metodo_pago}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el método de pago.');
    } finally {
      setEliminando(false);
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Métodos de pago</h1>
        </div>
        {puedeGestionar && <Link to="/metodos-pago/nuevo" className="btn btn-primary">+ Nuevo Método de pago</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Nombre</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={2} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && metodos.length === 0 && (
              <tr><td colSpan={2} style={{ textAlign: 'center' }}>No hay métodos de pago cargados.</td></tr>
            )}
            {metodos.map((metodo) => (
              <tr key={metodo.id_metodo_pago}>
                <td>{metodo.metodo_pago}</td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/metodos-pago/${metodo.id_metodo_pago}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(metodo)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar método de pago"
          mensaje={`¿Eliminar el método de pago "${aEliminar.metodo_pago}"?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}