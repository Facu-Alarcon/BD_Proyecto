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
import { PersonaCelda } from '../../components/Avatar';
import ContactoCelda from '../../components/ContactoCelda';
import { formatearDni, formatearTelefono } from '../../utils/formato';

export default function EmpleadosList() {
  const { puedeGestionar } = usePermiso('empleados');
  const [empleados, setEmpleados] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  function cargar() {
    setCargando(true);
    api
      .get('/empleados/')
      .then(({ data }) => setEmpleados(data))
      .catch(() => setError('No se pudieron cargar los empleados.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

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

  // Filtros de esta pantalla (ver hooks/useFiltros.js)
  const configFiltros = [
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
        <table className="data-table">
          <thead>
            <tr>
              <th>Empleado</th>
              <th>Contacto</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && empleados.length === 0 && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>No hay empleados cargados.</td></tr>
            )}
            <FilaSinResultados filtros={filtros} total={empleados.length} cargando={cargando} columnas={3} nombreItems="empleados" />
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
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/empleados/${empleado.id_empleado}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(empleado)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar empleado"
          mensaje={`¿Eliminar al empleado "${aEliminar.nombre_emp} ${aEliminar.apellido_emp}"?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}
