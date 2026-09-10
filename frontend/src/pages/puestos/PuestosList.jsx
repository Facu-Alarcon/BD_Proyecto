import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import { IconEditar, IconEliminar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';

export default function PuestosList() {
  const { puedeGestionar } = usePermiso('puestos');
  const [puestos, setPuestos] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  function cargar() {
    setCargando(true);
    api
      .get('/puestos/')
      .then(({ data }) => setPuestos(data))
      .catch(() => setError('No se pudieron cargar los puestos.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/puestos/${aEliminar.id_puesto}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el puesto.');
    } finally {
      setEliminando(false);
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Puestos</h1>
        </div>
        {puedeGestionar && <Link to="/puestos/nuevo" className="btn btn-primary">+ Nuevo Puesto</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Puesto</th>
              <th>Sueldo</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && puestos.length === 0 && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>No hay puestos cargados.</td></tr>
            )}
            {puestos.map((puesto) => (
              <tr key={puesto.id_puesto}>
                <td>{puesto.nombre_puesto}</td>
                <td>${Number(puesto.sueldo_monto).toLocaleString('es-AR')}</td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/puestos/${puesto.id_puesto}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(puesto)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar puesto"
          mensaje={`¿Eliminar el puesto "${aEliminar.nombre_puesto}"?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}
