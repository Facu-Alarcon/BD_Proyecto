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
import { PersonaCelda } from '../../components/Avatar';
import ContactoCelda from '../../components/ContactoCelda';
import { formatearDni, formatearTelefono } from '../../utils/formato';

// Lista de Empleados: tabla con buscador, paginación y botones para editar o eliminar.
export default function EmpleadosList() {
  // Qué puede hacer el usuario en este módulo según su perfil (si no puede gestionar, solo ve la tabla)
  const { puedeGestionar } = usePermiso('empleados');
  const [empleados, setEmpleados] = useState([]);
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
      .get('/empleados/')
      .then(({ data }) => setEmpleados(data))
      .catch(() => setError('No se pudieron cargar los empleados.'))
      .finally(() => setCargando(false));
  }

  // Se cargan una sola vez, al abrir la pantalla
  useEffect(cargar, []);

  // Se ejecuta al confirmar en la ventana de "¿Eliminar?". Si el backend no deja borrarlo
  // (por ejemplo, porque está en uso en otra tabla) se muestra el motivo que devuelve.
  // Eliminar lo borra de la base y no se puede recuperar. Si el empleado ya se usó en
  // las reservas, el backend no deja eliminarlo y el mensaje avisa que se puede desactivar.
  // Está explicado en infinito_sonido/baja_logica.py.
  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/empleados/${aEliminar.id_empleado}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el empleado.');
    } finally {
      setEliminando(false);
    }
  }

  // Se ejecuta al confirmar en la ventana de "¿Desactivar?". El empleado no se borra: queda
  // en esta lista con el cartel "Inactivo" y deja de aparecer para elegirlo en
  // las reservas nuevas. Si el backend no deja desactivarlo, se muestra el motivo.
  async function confirmarDesactivar() {
    setProcesando(true);
    try {
      await api.post(`/empleados/${aDesactivar.id_empleado}/desactivar/`);
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
      await api.post(`/empleados/${x.id_empleado}/reactivar/`);
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
    {
      tipo: 'texto', id: 'texto', placeholder: 'Nombre, apellido, DNI, teléfono o email',
      // DNI y teléfono van también con formato, así se encuentran escribiéndolos como se ven en la tabla
      campos: (e) => [`${e.nombre_emp} ${e.apellido_emp}`, e.dni, formatearDni(e.dni), e.telefono_emp, formatearTelefono(e.telefono_emp), e.email_emp],
    },
  ];
  const filtros = useFiltros(empleados, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Empleados</h1>
        </div>
        {puedeGestionar && <Link to="/empleados/nuevo" className="btn btn-primary">+ Nuevo Empleado</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={empleados.length} cargando={cargando} nombreItems="empleados" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
        {/* Tabla con las filas de la página actual (paginacion.visibles) */}
        <table className="data-table">
          <thead>
            <tr>
              <th>Empleado</th>
              <th>Contacto</th>
              <th>Estado</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={4} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && empleados.length === 0 && (
              <tr><td colSpan={4} style={{ textAlign: 'center' }}>No hay empleados cargados.</td></tr>
            )}
            <FilaSinResultados filtros={filtros} total={empleados.length} cargando={cargando} columnas={4} nombreItems="empleados" />
            {paginacion.visibles.map((empleado) => (
              <tr key={empleado.id_empleado}>
                {/* Abajo del nombre va el DNI con puntos; si no lo tiene, una etiqueta ámbar para que se note */}
                <td>
                  <PersonaCelda
                    nombre={empleado.nombre_emp}
                    apellido={empleado.apellido_emp}
                    detalle={empleado.dni ? `DNI ${formatearDni(empleado.dni)}` : <span className="badge badge-amber badge-chica">Sin DNI</span>}
                  />
                </td>
                {/* Mail y teléfono juntos en una sola columna */}
                <td><ContactoCelda email={empleado.email_emp} telefono={empleado.telefono_emp} /></td>
                {/* Cartelito verde si está activo, rojo si está desactivado */}
                <td>
                  {empleado.activo
                    ? <span className="badge badge-green">Activo</span>
                    : <span className="badge badge-red">Inactivo</span>}
                </td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/empleados/${empleado.id_empleado}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(empleado)} title="Eliminar"><IconEliminar /></button>
                      {empleado.activo ? (
                        <button type="button" className="btn btn-secondary btn-sm" onClick={() => setADesactivar(empleado)} title="Desactivar"><IconDesactivar /></button>
                      ) : (
                        <button type="button" className="btn btn-secondary btn-sm" onClick={() => reactivar(empleado)} title="Reactivar" disabled={procesando}><IconReactivar /></button>
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
          titulo="Eliminar empleado"
          mensaje={`¿Eliminar al empleado "${aEliminar.nombre_emp} ${aEliminar.apellido_emp}"?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}

      {/* Ventana que pregunta si de verdad se quiere desactivar (aparece al tocar el botón Desactivar) */}
      {aDesactivar && (
        <ConfirmModal
          titulo="Desactivar empleado"
          mensaje={`¿Desactivar al empleado "${aDesactivar.nombre_emp} ${aDesactivar.apellido_emp}"? Va a dejar de ofrecerse en las reservas nuevas, pero se conserva su historial y se puede volver a activar.`}
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
