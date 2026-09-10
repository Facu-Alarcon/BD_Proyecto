import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import { IconEditar, IconEliminar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';

export default function PermisosList() {
  const { puedeGestionar } = usePermiso('permisos');
  const [permisos, setPermisos] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  function cargar() {
    setCargando(true);
    api
      .get('/permisos/')
      .then(({ data }) => setPermisos(data))
      .catch(() => setError('No se pudieron cargar los permisos.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/permisos/${aEliminar.id_permiso}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el permiso.');
    } finally {
      setEliminando(false);
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Permisos</h1>
          <p>El código es la clave interna que usa el sistema para habilitar el acceso a cada módulo.</p>
        </div>
        {puedeGestionar && <Link to="/permisos/nuevo" className="btn btn-primary">+ Nuevo Permiso</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Nombre</th>
              <th>Código</th>
              <th>Descripción</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && permisos.length === 0 && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>No hay permisos cargados.</td></tr>
            )}
            {permisos.map((permiso) => (
              <tr key={permiso.id_permiso}>
                <td>{permiso.nombre_permiso}</td>
                <td><code style={{ fontSize: 12, color: 'var(--text-muted)' }}>{permiso.codigo}</code></td>
                <td>{permiso.descripcion_permiso}</td>
                <td>
                  {permiso.estado_permiso
                    ? <span className="badge badge-green">Activo</span>
                    : <span className="badge badge-gray">Inactivo</span>}
                </td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/permisos/${permiso.id_permiso}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(permiso)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar permiso"
          mensaje={`¿Eliminar el permiso "${aEliminar.nombre_permiso}"? Se quitará de todos los perfiles que lo tengan asignado.`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}
