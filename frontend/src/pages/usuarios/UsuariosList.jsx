import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import { IconEditar, IconEliminar, IconLlave, IconReactivar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';
import { PersonaCelda } from '../../components/Avatar';
import RestablecerClaveModal from '../../components/RestablecerClaveModal';

export default function UsuariosList() {
  const { puedeGestionar } = usePermiso('usuarios');
  const [usuarios, setUsuarios] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aDarDeBaja, setADarDeBaja] = useState(null);
  const [procesando, setProcesando] = useState(false);
  const [aRestablecer, setARestablecer] = useState(null);

  function cargar() {
    setCargando(true);
    api
      .get('/usuarios/')
      .then(({ data }) => setUsuarios(data))
      .catch(() => setError('No se pudieron cargar los usuarios.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function confirmarBaja() {
    setProcesando(true);
    try {
      await api.delete(`/usuarios/${aDarDeBaja.id_usuario}/`);
      setADarDeBaja(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo dar de baja al usuario.');
    } finally {
      setProcesando(false);
    }
  }

  async function reactivar(usuario) {
    setProcesando(true);
    try {
      await api.post(`/usuarios/${usuario.id_usuario}/reactivar/`);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo reactivar al usuario.');
    } finally {
      setProcesando(false);
    }
  }

  async function confirmarRestablecer(contraseña) {
    await api.post(`/usuarios/${aRestablecer.id_usuario}/restablecer-clave/`, { contraseña });
    setARestablecer(null);
    cargar();
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
              <th>DNI</th>
              <th>Apellido y Nombre</th>
              <th>Correo</th>
              <th>Usuario</th>
              <th>Perfil</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={7} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && usuarios.length === 0 && (
              <tr><td colSpan={7} style={{ textAlign: 'center' }}>No hay usuarios cargados.</td></tr>
            )}
            {usuarios.map((usuario) => (
              <tr key={usuario.id_usuario}>
                <td>{usuario.dni}</td>
                <td>
                  <PersonaCelda nombre={usuario.nombre} apellido={usuario.apellido} texto={`${usuario.apellido}, ${usuario.nombre}`} />
                </td>
                <td>{usuario.correo}</td>
                <td>{usuario.usuario}</td>
                <td>{usuario.perfil_nombre}</td>
                <td>
                  {usuario.activo
                    ? <span className="badge badge-green">Activo</span>
                    : <span className="badge badge-red">Inactivo</span>}
                  {usuario.activo && usuario.debe_cambiar_clave && (
                    <span className="badge badge-amber" style={{ marginLeft: 6 }}>Debe cambiar clave</span>
                  )}
                </td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/usuarios/${usuario.id_usuario}/editar`} className="btn btn-secondary btn-sm" title="Editar">
                        <IconEditar />
                      </Link>
                      <button type="button" className="btn btn-secondary btn-sm" onClick={() => setARestablecer(usuario)} title="Restablecer clave">
                        <IconLlave />
                      </button>
                      {usuario.activo ? (
                        <button type="button" className="btn btn-danger btn-sm" onClick={() => setADarDeBaja(usuario)} title="Dar de baja">
                          <IconEliminar />
                        </button>
                      ) : (
                        <button type="button" className="btn btn-secondary btn-sm" onClick={() => reactivar(usuario)} title="Reactivar" disabled={procesando}>
                          <IconReactivar />
                        </button>
                      )}
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

      {aDarDeBaja && (
        <ConfirmModal
          titulo="Dar de baja usuario"
          mensaje={`¿Dar de baja al usuario "${aDarDeBaja.usuario}"? Va a dejar de poder iniciar sesión, pero sus datos e historial se conservan.`}
          textoConfirmar="Dar de baja"
          confirmando={procesando}
          onCancelar={() => setADarDeBaja(null)}
          onConfirmar={confirmarBaja}
        />
      )}

      {aRestablecer && (
        <RestablecerClaveModal
          usuario={aRestablecer}
          onCancelar={() => setARestablecer(null)}
          onConfirmar={confirmarRestablecer}
        />
      )}
    </div>
  );
}