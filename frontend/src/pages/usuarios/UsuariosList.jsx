import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import BarraFiltros, { FilaSinResultados } from '../../components/BarraFiltros';
import { useFiltros, opcionesDe } from '../../hooks/useFiltros';
import Paginacion from '../../components/Paginacion';
import { usePaginacion } from '../../hooks/usePaginacion';
import { IconEditar, IconEliminar, IconLlave, IconReactivar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';
import { PersonaCelda } from '../../components/Avatar';
import RestablecerClaveModal from '../../components/RestablecerClaveModal';

// Lista de Usuarios: además de editar, permite restablecer la clave, dar de baja y reactivar.
export default function UsuariosList() {
  // Qué puede hacer el usuario en este módulo según su perfil (si no puede gestionar, solo ve la tabla)
  const { puedeGestionar } = usePermiso('usuarios');
  const [usuarios, setUsuarios] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aDarDeBaja, setADarDeBaja] = useState(null);
  const [procesando, setProcesando] = useState(false);
  const [aRestablecer, setARestablecer] = useState(null);

  // Trae todos los registros del backend y los guarda para la tabla
  function cargar() {
    setCargando(true);
    api
      .get('/usuarios/')
      .then(({ data }) => setUsuarios(data))
      .catch(() => setError('No se pudieron cargar los usuarios.'))
      .finally(() => setCargando(false));
  }

  // Se cargan una sola vez, al abrir la pantalla
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

  // Pide a la API una contraseña temporal nueva; la API se la manda por mail al empleado.
  // Se devuelve la respuesta para que la ventana muestre si el mail salió o no.
  async function confirmarRestablecer() {
    const { data } = await api.post(`/usuarios/${aRestablecer.id_usuario}/restablecer-clave/`);
    return data;
  }

  // Al cerrar la ventana después de restablecer, se recarga la lista (cambia "Debe cambiar clave")
  function terminarRestablecer() {
    setARestablecer(null);
    cargar();
  }

  // Filtros de esta pantalla (ver hooks/useFiltros.js)
  const configFiltros = [
    {
      tipo: 'texto', id: 'texto', placeholder: 'Nombre, apellido, DNI, usuario o correo',
      campos: (u) => [`${u.nombre} ${u.apellido}`, `${u.apellido} ${u.nombre}`, u.dni, u.usuario, u.correo],
    },
    { tipo: 'select', id: 'perfil', label: 'Perfil', valor: (u) => u.perfil_nombre, opciones: opcionesDe(usuarios, (u) => u.perfil_nombre) },
    {
      tipo: 'select', id: 'estado', label: 'Estado', valor: (u) => (u.activo ? 'activo' : 'inactivo'),
      opciones: [{ value: 'activo', label: 'Activos' }, { value: 'inactivo', label: 'Dados de baja' }],
    },
  ];
  const filtros = useFiltros(usuarios, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Usuarios</h1>
        </div>
        {puedeGestionar && <Link to="/usuarios/nuevo" className="btn btn-primary">+ Nuevo Usuario</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={usuarios.length} cargando={cargando} nombreItems="usuarios" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
        {/* Tabla con las filas de la página actual (paginacion.visibles) */}
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
            <FilaSinResultados filtros={filtros} total={usuarios.length} cargando={cargando} columnas={7} nombreItems="usuarios" />
            {paginacion.visibles.map((usuario) => (
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
        <Paginacion paginacion={paginacion} />
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
          onTerminar={terminarRestablecer}
        />
      )}
    </div>
  );
}