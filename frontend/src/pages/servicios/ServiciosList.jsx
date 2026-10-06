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
import { iconoServicio } from '../../utils/iconosModulos';

// Lista de Servicios: cada uno con su precio y cuántos equipos usa.
export default function ServiciosList() {
  // Qué puede hacer el usuario en este módulo según su perfil (si no puede gestionar, solo ve la tabla)
  const { puedeGestionar } = usePermiso('servicios');
  const [servicios, setServicios] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  // Trae todos los registros del backend y los guarda para la tabla
  function cargar() {
    setCargando(true);
    api
      .get('/servicios/')
      .then(({ data }) => setServicios(data))
      .catch(() => setError('No se pudieron cargar los servicios.'))
      .finally(() => setCargando(false));
  }

  // Se cargan una sola vez, al abrir la pantalla
  useEffect(cargar, []);

  // Se ejecuta al confirmar en la ventana de "¿Eliminar?". Si el backend no deja borrarlo
  // (por ejemplo, porque está en uso en otra tabla) se muestra el motivo que devuelve.
  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/servicios/${aEliminar.id_servicio}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el servicio.');
    } finally {
      setEliminando(false);
    }
  }

  // Filtros de esta pantalla (ver hooks/useFiltros.js)
  const configFiltros = [
    { tipo: 'texto', id: 'texto', placeholder: 'Nombre del servicio', campos: (s) => [s.tipo_servicio] },
    { tipo: 'rango', id: 'precio', label: 'Precio', input: 'number', valor: (s) => s.precio_servicio },
  ];
  const filtros = useFiltros(servicios, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Servicios</h1>
        </div>
        {puedeGestionar && <Link to="/servicios/nuevo" className="btn btn-primary">+ Nuevo Servicio</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={servicios.length} cargando={cargando} nombreItems="servicios" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
        {/* Tabla con las filas de la página actual (paginacion.visibles) */}
        <table className="data-table">
          <thead>
            <tr>
              <th>Servicio</th>
              <th>Precio</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && servicios.length === 0 && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>No hay servicios cargados.</td></tr>
            )}
            <FilaSinResultados filtros={filtros} total={servicios.length} cargando={cargando} columnas={3} nombreItems="servicios" />
            {paginacion.visibles.map((servicio) => (
              <tr key={servicio.id_servicio}>
                {/* Abajo del nombre: cuántos equipos usa (o un aviso si todavía no se cargaron) */}
                <td>
                  <IconoCelda
                    {...iconoServicio(servicio.tipo_servicio)}
                    nombre={servicio.tipo_servicio}
                    detalle={servicio.equipos_detalle?.length ? `Usa ${servicio.equipos_detalle.length} equipos` : 'Sin equipos cargados'}
                  />
                </td>
                <td>${Number(servicio.precio_servicio).toLocaleString('es-AR')}</td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/servicios/${servicio.id_servicio}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(servicio)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar servicio"
          mensaje={`¿Eliminar el servicio "${aEliminar.tipo_servicio}"?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}
