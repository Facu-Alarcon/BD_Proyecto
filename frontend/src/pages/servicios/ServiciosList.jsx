import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import BarraFiltros, { FilaSinResultados } from '../../components/BarraFiltros';
import { useFiltros } from '../../hooks/useFiltros';
import Paginacion from '../../components/Paginacion';
import { usePaginacion } from '../../hooks/usePaginacion';
import { IconDesactivar, IconEditar, IconEliminar, IconReactivar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';
import IconoCelda from '../../components/IconoCelda';
import { iconoServicio } from '../../utils/iconosModulos';

// Lista de Servicios: cada uno con su precio y cuántos equipos usa.
// Texto de los equipos que usa un servicio, sumando las cantidades (no la cantidad de
// tipos distintos): 4 bafles y 2 luces -> "Usa 6 equipos: 4 Bafle, 2 Par LED"
function textoEquipos(equipos) {
  if (!equipos?.length) return 'Sin equipos cargados';
  const total = equipos.reduce((suma, e) => suma + Number(e.cantidad), 0);
  const nombres = equipos.map((e) => `${e.cantidad} ${e.nombre_equipo}`).join(', ');
  return `Usa ${total} ${total === 1 ? 'equipo' : 'equipos'}: ${nombres}`;
}

export default function ServiciosList() {
  // Qué puede hacer el usuario en este módulo según su perfil (si no puede gestionar, solo ve la tabla)
  const { puedeGestionar } = usePermiso('servicios');
  const [servicios, setServicios] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);
  // El que se está por desactivar. Cuando tiene algo, se abre la ventana que pregunta "¿Desactivar?"
  const [aDesactivar, setADesactivar] = useState(null);
  // Se pone en true mientras esperamos la respuesta del backend, para que no aprieten dos veces
  const [procesando, setProcesando] = useState(false);

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
  // Eliminar lo borra de la base y no se puede recuperar. Si el servicio ya se usó en
  // las reservas, el backend no deja eliminarlo y el mensaje avisa que se puede desactivar.
  // Está explicado en infinito_sonido/baja_logica.py.
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

  // Se ejecuta al confirmar en la ventana de "¿Desactivar?". El servicio no se borra: queda
  // en esta lista con el cartel "Inactivo" y deja de aparecer para elegirlo en
  // las reservas nuevas. Si el backend no deja desactivarlo, se muestra el motivo.
  async function confirmarDesactivar() {
    setProcesando(true);
    try {
      await api.post(`/servicios/${aDesactivar.id_servicio}/desactivar/`);
      setADesactivar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo desactivar.');
    } finally {
      setProcesando(false);
    }
  }

  // Botón Reactivar (solo lo tienen los inactivos): lo vuelve a dejar activo.
  // No pide confirmación porque no se pierde nada.
  async function reactivar(x) {
    setProcesando(true);
    try {
      await api.post(`/servicios/${x.id_servicio}/reactivar/`);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo reactivar.');
    } finally {
      setProcesando(false);
    }
  }

  // Filtros de esta pantalla (ver hooks/useFiltros.js)
  const configFiltros = [
    // Filtro para ver solo los activos o solo los inactivos
    {
      tipo: 'select', id: 'estado', label: 'Estado', valor: (x) => (x.activo ? 'activo' : 'inactivo'),
      opciones: [{ value: 'activo', label: 'Activos' }, { value: 'inactivo', label: 'Inactivos' }],
    },
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
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={4} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && servicios.length === 0 && (
              <tr><td colSpan={4} style={{ textAlign: 'center' }}>No hay servicios cargados.</td></tr>
            )}
            <FilaSinResultados filtros={filtros} total={servicios.length} cargando={cargando} columnas={4} nombreItems="servicios" />
            {paginacion.visibles.map((servicio) => (
              <tr key={servicio.id_servicio}>
                {/* Abajo del nombre: cuántos equipos usa (o un aviso si todavía no se cargaron) */}
                <td>
                  <IconoCelda
                    {...iconoServicio(servicio.tipo_servicio)}
                    nombre={servicio.tipo_servicio}
                    detalle={textoEquipos(servicio.equipos_detalle)}
                  />
                </td>
                <td>${Number(servicio.precio_servicio).toLocaleString('es-AR')}</td>
                {/* Cartelito verde si está activo, rojo si está desactivado */}
                <td>
                  {servicio.activo
                    ? <span className="badge badge-green">Activo</span>
                    : <span className="badge badge-red">Inactivo</span>}
                </td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/servicios/${servicio.id_servicio}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(servicio)} title="Eliminar"><IconEliminar /></button>
                      {servicio.activo ? (
                        <button type="button" className="btn btn-secondary btn-sm" onClick={() => setADesactivar(servicio)} title="Desactivar"><IconDesactivar /></button>
                      ) : (
                        <button type="button" className="btn btn-secondary btn-sm" onClick={() => reactivar(servicio)} title="Reactivar" disabled={procesando}><IconReactivar /></button>
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

      {/* Ventana que pregunta si de verdad se quiere desactivar (aparece al tocar el botón Desactivar) */}
      {aDesactivar && (
        <ConfirmModal
          titulo="Desactivar servicio"
          mensaje={`¿Desactivar el servicio "${aDesactivar.tipo_servicio}"? Va a dejar de ofrecerse en las reservas nuevas, pero se conserva su historial y se puede volver a activar.`}
          textoConfirmar="Desactivar"
          textoConfirmando="Desactivando..."
          confirmando={procesando}
          onCancelar={() => setADesactivar(null)}
          onConfirmar={confirmarDesactivar}
        />
      )}
    </div>
  );
}
