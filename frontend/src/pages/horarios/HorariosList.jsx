import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import { IconEditar, IconEliminar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';

export default function HorariosList() {
  const { puedeGestionar } = usePermiso('horarios');
  const [horarios, setHorarios] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  function cargar() {
    setCargando(true);
    api
      .get('/horarios/')
      .then(({ data }) => setHorarios(data))
      .catch(() => setError('No se pudieron cargar los horarios.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/horarios/${aEliminar.id_horario}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el horario.');
    } finally {
      setEliminando(false);
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Horarios</h1>
        </div>
        {puedeGestionar && <Link to="/horarios/nuevo" className="btn btn-primary">+ Nuevo Horario</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Cantidad de horas</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={2} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && horarios.length === 0 && (
              <tr><td colSpan={2} style={{ textAlign: 'center' }}>No hay horarios cargados.</td></tr>
            )}
            {horarios.map((horario) => (
              <tr key={horario.id_horario}>
                <td>{horario.cantidad_horas} hs</td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/horarios/${horario.id_horario}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(horario)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar horario"
          mensaje={`¿Eliminar el horario de ${aEliminar.cantidad_horas} hs?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}