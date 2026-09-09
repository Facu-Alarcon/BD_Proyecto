import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';

export default function PermisosList() {
  const { puedeGestionar } = usePermiso('permisos');
  const [permisos, setPermisos] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  function cargar() {
    setCargando(true);
    api
      .get('/permisos/')
      .then(({ data }) => setPermisos(data))
      .catch(() => setError('No se pudieron cargar los permisos.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function eliminar(permiso) {
    if (!window.confirm(`¿Eliminar el permiso "${permiso.nombre_permiso}"? Se quitará de todos los perfiles que lo tengan asignado.`)) return;
    try {
      await api.delete(`/permisos/${permiso.id_permiso}/`);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el permiso.');
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
                    <>
                      <Link to={`/permisos/${permiso.id_permiso}/editar`} className="btn btn-secondary btn-sm">Editar</Link>{' '}
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => eliminar(permiso)}>Eliminar</button>
                    </>
                  ) : (
                    <span className="form-hint">Solo lectura</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
