import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import { IconEditar, IconEliminar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';

export default function SueldosList() {
  const { puedeGestionar } = usePermiso('sueldos');
  const [sueldos, setSueldos] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  function cargar() {
    setCargando(true);
    api
      .get('/sueldos/')
      .then(({ data }) => setSueldos(data))
      .catch(() => setError('No se pudieron cargar los sueldos.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/sueldos/${aEliminar.id_sueldo}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el sueldo.');
    } finally {
      setEliminando(false);
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Sueldos</h1>
        </div>
        {puedeGestionar && <Link to="/sueldos/nuevo" className="btn btn-primary">+ Nuevo Sueldo</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Monto</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={2} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && sueldos.length === 0 && (
              <tr><td colSpan={2} style={{ textAlign: 'center' }}>No hay sueldos cargados.</td></tr>
            )}
            {sueldos.map((sueldo) => (
              <tr key={sueldo.id_sueldo}>
                <td>${Number(sueldo.monto_sueldo).toLocaleString('es-AR')}</td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/sueldos/${sueldo.id_sueldo}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(sueldo)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar sueldo"
          mensaje={`¿Eliminar el sueldo de $${Number(aEliminar.monto_sueldo).toLocaleString('es-AR')}?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}
