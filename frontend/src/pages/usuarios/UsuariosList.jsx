import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';

export default function UsuariosList() {
  const { puedeGestionar } = usePermiso('usuarios');
  const [usuarios, setUsuarios] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  function cargar() {
    setCargando(true);
    api
      .get('/usuarios/')
      .then(({ data }) => setUsuarios(data))
      .catch(() => setError('No se pudieron cargar los usuarios.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function eliminar(usuario) {
    if (!window.confirm(`¿Eliminar al usuario "${usuario.usuario}"?`)) return;
    try {
      await api.delete(`/usuarios/${usuario.id_usuario}/`);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el usuario.');
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Usuarios</h1>
        </div>
        {puedeGestionar && <Link to="/usuarios/nuevo" className="btn btn-primary">+ Nuevo Usuario</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Usuario</th>
              <th>Perfil</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && usuarios.length === 0 && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>No hay usuarios cargados.</td></tr>
            )}
            {usuarios.map((usuario) => (
              <tr key={usuario.id_usuario}>
                <td>{usuario.usuario}</td>
                <td>{usuario.perfil_nombre}</td>
                <td>
                  {puedeGestionar ? (
                    <>
                      <Link to={`/usuarios/${usuario.id_usuario}/editar`} className="btn btn-secondary btn-sm">Editar</Link>{' '}
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => eliminar(usuario)}>Eliminar</button>
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
