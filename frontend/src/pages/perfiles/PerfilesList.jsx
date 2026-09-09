import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';

export default function PerfilesList() {
  const { puedeGestionar } = usePermiso('perfiles');
  const [perfiles, setPerfiles] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  function cargar() {
    setCargando(true);
    api
      .get('/perfiles/')
      .then(({ data }) => setPerfiles(data))
      .catch(() => setError('No se pudieron cargar los perfiles.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function eliminar(perfil) {
    if (!window.confirm(`¿Eliminar el perfil "${perfil.tipo_perfil}"?`)) return;
    try {
      await api.delete(`/perfiles/${perfil.id_perfil}/`);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el perfil.');
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Perfiles</h1>
        </div>
        {puedeGestionar && <Link to="/perfiles/nuevo" className="btn btn-primary">+ Nuevo Perfil</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Nombre del Perfil</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={2} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && perfiles.length === 0 && (
              <tr><td colSpan={2} style={{ textAlign: 'center' }}>No hay perfiles cargados.</td></tr>
            )}
            {perfiles.map((perfil) => (
              <tr key={perfil.id_perfil}>
                <td>{perfil.tipo_perfil}</td>
                <td>
                  {puedeGestionar ? (
                    <>
                      <Link to={`/perfiles/${perfil.id_perfil}/permisos`} className="btn btn-secondary btn-sm">Permisos</Link>{' '}
                      <Link to={`/perfiles/${perfil.id_perfil}/editar`} className="btn btn-secondary btn-sm">Editar</Link>{' '}
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => eliminar(perfil)}>Eliminar</button>
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
