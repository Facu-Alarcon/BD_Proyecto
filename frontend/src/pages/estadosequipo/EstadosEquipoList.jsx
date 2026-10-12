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
import { colorEstadoEquipo } from '../../utils/estadoEquipo';

// Lista de Estados de equipo (Disponible, En uso, En reparación...): tabla con buscador
// y botones para editar o eliminar. Antes los estados se agregaban desde el formulario
// de Equipos con un botón "+"; ahora tienen su propio módulo.
export default function EstadosEquipoList() {
  // Qué puede hacer el usuario en este módulo según su perfil (si no puede gestionar, solo ve la tabla)
  const { puedeGestionar } = usePermiso('estados_equipo');
  const [estados, setEstados] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  // Trae todos los registros del backend y los guarda para la tabla
  function cargar() {
    setCargando(true);
    api
      .get('/estado-equipos/')
      .then(({ data }) => setEstados(data))
      .catch(() => setError('No se pudieron cargar los estados de equipo.'))
      .finally(() => setCargando(false));
  }

  // Se cargan una sola vez, al abrir la pantalla
  useEffect(cargar, []);

  // Se ejecuta al confirmar en la ventana de "¿Eliminar?". Si el backend no deja borrarlo
  // (porque hay equipos que tienen ese estado) se muestra el motivo que devuelve.
  // Es una baja física: el registro se borra de la base y no se puede recuperar.
  // Ver infinito_sonido/baja_logica.py.
  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/estado-equipos/${aEliminar.id_estadoeq}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el estado de equipo.');
    } finally {
      setEliminando(false);
    }
  }

  // Filtros de esta pantalla (ver hooks/useFiltros.js)
  const configFiltros = [
    { tipo: 'texto', id: 'texto', placeholder: 'Nombre del estado', campos: (e) => [e.nombre_estadoeq] },
  ];
  const filtros = useFiltros(estados, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Estados de equipo</h1>
        </div>
        {puedeGestionar && <Link to="/estados-equipo/nuevo" className="btn btn-primary">+ Nuevo Estado de equipo</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={estados.length} cargando={cargando} nombreItems="estados de equipo" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
        {/* Tabla con las filas de la página actual (paginacion.visibles) */}
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
            {!cargando && estados.length === 0 && (
              <tr><td colSpan={2} style={{ textAlign: 'center' }}>No hay estados de equipo cargados.</td></tr>
            )}
            <FilaSinResultados filtros={filtros} total={estados.length} cargando={cargando} columnas={2} nombreItems="estados de equipo" />
            {paginacion.visibles.map((estado) => (
              <tr key={estado.id_estadoeq}>
                {/* El nombre va con el mismo cartelito de color que se ve en la lista de Equipos */}
                <td><span className={`badge ${colorEstadoEquipo(estado.nombre_estadoeq).badge}`}>{estado.nombre_estadoeq}</span></td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/estados-equipo/${estado.id_estadoeq}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(estado)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar estado de equipo"
          mensaje={`¿Eliminar el estado de equipo "${aEliminar.nombre_estadoeq}"?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}