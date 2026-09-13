import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import { IconEditar, IconEliminar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';

export default function TiposEquipoList() {
  const { puedeGestionar } = usePermiso('tipos_equipo');
  const [tipos, setTipos] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  function cargar() {
    setCargando(true);
    api
      .get('/tipo-equipos/')
      .then(({ data }) => setTipos(data))
      .catch(() => setError('No se pudieron cargar los tipos de equipo.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/tipo-equipos/${aEliminar.id_tipoeq}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el tipo de equipo.');
    } finally {
      setEliminando(false);
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Tipos de equipo</h1>
        </div>
        {puedeGestionar && <Link to="/tipos-equipo/nuevo" className="btn btn-primary">+ Nuevo Tipo de equipo</Link>}
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
            {!cargando && tipos.length === 0 && (
              <tr><td colSpan={2} style={{ textAlign: 'center' }}>No hay tipos de equipo cargados.</td></tr>
            )}
            {tipos.map((tipo) => (
              <tr key={tipo.id_tipoeq}>
                <td>{tipo.nombre_tipoeq}</td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/tipos-equipo/${tipo.id_tipoeq}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(tipo)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar tipo de equipo"
          mensaje={`¿Eliminar el tipo de equipo "${aEliminar.nombre_tipoeq}"?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}