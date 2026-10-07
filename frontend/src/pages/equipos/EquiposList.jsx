import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { colorEstadoEquipo } from '../../utils/estadoEquipo';
import { usePermiso } from '../../hooks/usePermiso';
import BarraFiltros, { FilaSinResultados } from '../../components/BarraFiltros';
import { useFiltros, opcionesDe } from '../../hooks/useFiltros';
import Paginacion from '../../components/Paginacion';
import { usePaginacion } from '../../hooks/usePaginacion';
import { IconEditar, IconEliminar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';
import IconoCelda from '../../components/IconoCelda';
import { iconoEquipo } from '../../utils/iconosModulos';

// Lista de Equipos: tabla con buscador, filtros por tipo y estado, y botones para editar o eliminar.
export default function EquiposList() {
  // Qué puede hacer el usuario en este módulo según su perfil (si no puede gestionar, solo ve la tabla)
  const { puedeGestionar } = usePermiso('equipos');
  const [equipos, setEquipos] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  // Trae todos los registros del backend y los guarda para la tabla
  function cargar() {
    setCargando(true);
    api
      .get('/equipos/')
      .then(({ data }) => setEquipos(data))
      .catch(() => setError('No se pudieron cargar los equipos.'))
      .finally(() => setCargando(false));
  }

  // Se cargan una sola vez, al abrir la pantalla
  useEffect(cargar, []);

  // Se ejecuta al confirmar en la ventana de "¿Eliminar?". Si el backend no deja borrarlo
  // (por ejemplo, porque está en uso en otra tabla) se muestra el motivo que devuelve.
  // Para el usuario es eliminar, pero el backend no lo borra de la base: lo da de baja (activo=False)
  // y el programador lo puede recuperar desde /admin. Ver infinito_sonido/baja_logica.py.
  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/equipos/${aEliminar.id_equipo}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el equipo.');
    } finally {
      setEliminando(false);
    }
  }

  // Filtros de esta pantalla (ver hooks/useFiltros.js)
  const configFiltros = [
    { tipo: 'texto', id: 'texto', placeholder: 'Nombre del equipo', campos: (e) => [e.nombre_equipo] },
    { tipo: 'select', id: 'tipo', label: 'Tipo', valor: (e) => e.tipo_nombre, opciones: opcionesDe(equipos, (e) => e.tipo_nombre) },
    { tipo: 'select', id: 'estado', label: 'Estado', valor: (e) => e.estado_nombre, opciones: opcionesDe(equipos, (e) => e.estado_nombre) },
  ];
  const filtros = useFiltros(equipos, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Equipos</h1>
        </div>
        {puedeGestionar && <Link to="/equipos/nuevo" className="btn btn-primary">+ Nuevo Equipo</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={equipos.length} cargando={cargando} nombreItems="equipos" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
        {/* Tabla con las filas de la página actual (paginacion.visibles) */}
        <table className="data-table">
          <thead>
            <tr>
              <th>Nombre</th>
              <th>Tipo</th>
              <th>Estado</th>
              <th>Cantidad</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && equipos.length === 0 && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>No hay equipos cargados.</td></tr>
            )}
            <FilaSinResultados filtros={filtros} total={equipos.length} cargando={cargando} columnas={5} nombreItems="equipos" />
            {paginacion.visibles.map((equipo) => (
              <tr key={equipo.id_equipo}>
                <td><IconoCelda {...iconoEquipo(equipo.nombre_equipo, equipo.tipo_nombre)} nombre={equipo.nombre_equipo} /></td>
                <td>{equipo.tipo_nombre}</td>
                <td><span className={`badge ${colorEstadoEquipo(equipo.estado_nombre).badge}`}>{equipo.estado_nombre}</span></td>
                <td>{equipo.cantidad_equipo}</td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/equipos/${equipo.id_equipo}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(equipo)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar equipo"
          mensaje={`¿Eliminar el equipo "${aEliminar.nombre_equipo}"?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}
