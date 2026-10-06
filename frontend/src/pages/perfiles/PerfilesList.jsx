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
import { iconoPerfil } from '../../utils/iconosModulos';

// Lista de Perfiles de usuario: tabla con buscador y botones para editar (y asignar permisos) o eliminar.
export default function PerfilesList() {
  // Qué puede hacer el usuario en este módulo según su perfil (si no puede gestionar, solo ve la tabla)
  const { puedeGestionar } = usePermiso('perfiles');
  const [perfiles, setPerfiles] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  // Trae todos los registros del backend y los guarda para la tabla
  function cargar() {
    setCargando(true);
    api
      .get('/perfiles/')
      .then(({ data }) => setPerfiles(data))
      .catch(() => setError('No se pudieron cargar los perfiles.'))
      .finally(() => setCargando(false));
  }

  // Se cargan una sola vez, al abrir la pantalla
  useEffect(cargar, []);

  // Se ejecuta al confirmar en la ventana de "¿Eliminar?". Si el backend no deja borrarlo
  // (por ejemplo, porque está en uso en otra tabla) se muestra el motivo que devuelve.
  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/perfiles/${aEliminar.id_perfil}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el perfil.');
    } finally {
      setEliminando(false);
    }
  }

  // Filtros de esta pantalla (ver hooks/useFiltros.js)
  const configFiltros = [
    { tipo: 'texto', id: 'texto', placeholder: 'Nombre del perfil', campos: (p) => [p.tipo_perfil] },
  ];
  const filtros = useFiltros(perfiles, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Perfiles</h1>
        </div>
        {puedeGestionar && <Link to="/perfiles/nuevo" className="btn btn-primary">+ Nuevo Perfil</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={perfiles.length} cargando={cargando} nombreItems="perfiles" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
        {/* Tabla con las filas de la página actual (paginacion.visibles) */}
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
            <FilaSinResultados filtros={filtros} total={perfiles.length} cargando={cargando} columnas={2} nombreItems="perfiles" />
            {paginacion.visibles.map((perfil) => (
              <tr key={perfil.id_perfil}>
                <td><IconoCelda {...iconoPerfil(perfil.tipo_perfil)} nombre={perfil.tipo_perfil} /></td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/perfiles/${perfil.id_perfil}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(perfil)} title="Eliminar"><IconEliminar /></button>
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

      {/* Ventana para confirmar el borrado (solo aparece cuando se tocó el tachito de alguna fila) */}
      {aEliminar && (
        <ConfirmModal
          titulo="Eliminar perfil"
          mensaje={`¿Eliminar el perfil "${aEliminar.tipo_perfil}"?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}
