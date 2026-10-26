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
import { iconoMetodoPago } from '../../utils/iconosModulos';

// Lista de Métodos de pago: tabla con buscador y botones para editar o eliminar.
export default function MetodosPagoList() {
  // Qué puede hacer el usuario en este módulo según su perfil (si no puede gestionar, solo ve la tabla)
  const { puedeGestionar } = usePermiso('metodos_pago');
  const [metodos, setMetodos] = useState([]);
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
      .get('/metodos-pago/')
      .then(({ data }) => setMetodos(data))
      .catch(() => setError('No se pudieron cargar los métodos de pago.'))
      .finally(() => setCargando(false));
  }

  // Se cargan una sola vez, al abrir la pantalla
  useEffect(cargar, []);

  // Se ejecuta al confirmar en la ventana de "¿Eliminar?". Si el backend no deja borrarlo
  // (por ejemplo, porque está en uso en otra tabla) se muestra el motivo que devuelve.
  // Eliminar lo borra de la base y no se puede recuperar. Si el método de pago ya se usó en
  // los pagos, el backend no deja eliminarlo y el mensaje avisa que se puede desactivar.
  // Está explicado en infinito_sonido/baja_logica.py.
  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/metodos-pago/${aEliminar.id_metodo_pago}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el método de pago.');
    } finally {
      setEliminando(false);
    }
  }

  // Se ejecuta al confirmar en la ventana de "¿Desactivar?". El método de pago no se borra: queda
  // en esta lista con el cartel "Inactivo" y deja de aparecer para elegirlo en
  // los pagos nuevos. Si el backend no deja desactivarlo, se muestra el motivo.
  async function confirmarDesactivar() {
    setProcesando(true);
    try {
      await api.post(`/metodos-pago/${aDesactivar.id_metodo_pago}/desactivar/`);
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
      await api.post(`/metodos-pago/${x.id_metodo_pago}/reactivar/`);
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
    { tipo: 'texto', id: 'texto', placeholder: 'Nombre del método', campos: (m) => [m.metodo_pago] },
  ];
  const filtros = useFiltros(metodos, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Métodos de pago</h1>
        </div>
        {puedeGestionar && <Link to="/metodos-pago/nuevo" className="btn btn-primary">+ Nuevo Método de pago</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={metodos.length} cargando={cargando} nombreItems="métodos de pago" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
        {/* Tabla con las filas de la página actual (paginacion.visibles) */}
        <table className="data-table">
          <thead>
            <tr>
              <th>Nombre</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && metodos.length === 0 && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>No hay métodos de pago cargados.</td></tr>
            )}
            <FilaSinResultados filtros={filtros} total={metodos.length} cargando={cargando} columnas={3} nombreItems="métodos de pago" />
            {paginacion.visibles.map((metodo) => (
              <tr key={metodo.id_metodo_pago}>
                <td><IconoCelda {...iconoMetodoPago(metodo.metodo_pago)} nombre={metodo.metodo_pago} /></td>
                {/* Cartelito verde si está activo, rojo si está desactivado */}
                <td>
                  {metodo.activo
                    ? <span className="badge badge-green">Activo</span>
                    : <span className="badge badge-red">Inactivo</span>}
                </td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/metodos-pago/${metodo.id_metodo_pago}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(metodo)} title="Eliminar"><IconEliminar /></button>
                      {metodo.activo ? (
                        <button type="button" className="btn btn-secondary btn-sm" onClick={() => setADesactivar(metodo)} title="Desactivar"><IconDesactivar /></button>
                      ) : (
                        <button type="button" className="btn btn-secondary btn-sm" onClick={() => reactivar(metodo)} title="Reactivar" disabled={procesando}><IconReactivar /></button>
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
          titulo="Eliminar método de pago"
          mensaje={`¿Eliminar el método de pago "${aEliminar.metodo_pago}"?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}

      {/* Ventana que pregunta si de verdad se quiere desactivar (aparece al tocar el botón Desactivar) */}
      {aDesactivar && (
        <ConfirmModal
          titulo="Desactivar método de pago"
          mensaje={`¿Desactivar el método de pago "${aDesactivar.metodo_pago}"? Va a dejar de ofrecerse en los pagos nuevos, pero se conserva su historial y se puede volver a activar.`}
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