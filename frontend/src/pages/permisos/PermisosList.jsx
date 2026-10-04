import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import BarraFiltros, { FilaSinResultados } from '../../components/BarraFiltros';
import { useFiltros } from '../../hooks/useFiltros';
import Paginacion from '../../components/Paginacion';
import { usePaginacion } from '../../hooks/usePaginacion';
import { IconEditar, IconEliminar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';
import IconoCelda from '../../components/IconoCelda';
import { iconoPermiso } from '../../utils/iconosModulos';

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

  // Filtros de esta pantalla (ver hooks/useFiltros.js)
  const configFiltros = [
    { tipo: 'texto', id: 'texto', placeholder: 'Nombre o descripción', campos: (p) => [p.nombre_permiso, p.descripcion_permiso] },
    {
      // Los permisos "ver_" son de solo lectura y los "gestionar_" dejan modificar
      tipo: 'select', id: 'clase', label: 'Tipo',
      valor: (p) => (p.codigo?.startsWith('ver_') ? 'ver' : p.codigo?.startsWith('gestionar_') ? 'gestionar' : 'otro'),
      opciones: [{ value: 'ver', label: 'Ver' }, { value: 'gestionar', label: 'Gestionar' }, { value: 'otro', label: 'Otros' }],
    },
    {
      tipo: 'select', id: 'estado', label: 'Estado', valor: (p) => (p.estado_permiso ? 'activo' : 'inactivo'),
      opciones: [{ value: 'activo', label: 'Activos' }, { value: 'inactivo', label: 'Inactivos' }],
    },
  ];
  const filtros = useFiltros(permisos, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Permisos</h1>
        </div>
        {puedeGestionar && <Link to="/permisos/nuevo" className="btn btn-primary">+ Nuevo Permiso</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={permisos.length} cargando={cargando} nombreItems="permisos" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
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
            <FilaSinResultados filtros={filtros} total={permisos.length} cargando={cargando} columnas={5} nombreItems="permisos" />
            {paginacion.visibles.map((permiso) => (
              <tr key={permiso.id_permiso}>
                <td><IconoCelda {...iconoPermiso(permiso.codigo)} nombre={permiso.nombre_permiso} /></td>
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
        <Paginacion paginacion={paginacion} />
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
