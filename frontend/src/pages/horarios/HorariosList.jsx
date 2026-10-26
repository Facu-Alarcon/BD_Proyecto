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
import UsoCelda from '../../components/UsoCelda';
import { iconoHorario } from '../../utils/iconosModulos';

// Lista de Horarios: cargas horarias, con filtro por cantidad de horas.
export default function HorariosList() {
  // Qué puede hacer el usuario en este módulo según su perfil (si no puede gestionar, solo ve la tabla)
  const { puedeGestionar } = usePermiso('horarios');
  const [horarios, setHorarios] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  // Trae todos los registros del backend y los guarda para la tabla
  function cargar() {
    setCargando(true);
    api
      .get('/horarios/')
      .then(({ data }) => setHorarios(data))
      .catch(() => setError('No se pudieron cargar los horarios.'))
      .finally(() => setCargando(false));
  }

  // Se cargan una sola vez, al abrir la pantalla
  useEffect(cargar, []);

  // Se ejecuta al confirmar en la ventana de "¿Eliminar?". Si el backend no deja borrarlo
  // (por ejemplo, porque está en uso en otra tabla) se muestra el motivo que devuelve.
  // Es una baja física: el registro se borra de la base y no se puede recuperar.
  // Ver infinito_sonido/baja_logica.py.
  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/horarios/${aEliminar.id_horario}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el horario.');
    } finally {
      setEliminando(false);
    }
  }

  // Filtros de esta pantalla (ver hooks/useFiltros.js)
  const configFiltros = [
    { tipo: 'rango', id: 'horas', label: 'Horas', input: 'number', valor: (h) => h.cantidad_horas },
  ];
  const filtros = useFiltros(horarios, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Horarios</h1>
          <p>Cargas horarias que se pueden asignar a los empleados desde su ficha.</p>
        </div>
        {puedeGestionar && <Link to="/horarios/nuevo" className="btn btn-primary">+ Nuevo Horario</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={horarios.length} cargando={cargando} nombreItems="horarios" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
        {/* Tabla con las filas de la página actual (paginacion.visibles) */}
        <table className="data-table">
          <thead>
            <tr>
              <th>Horario</th>
              <th>Empleados</th>
              <th className="col-acciones">Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && horarios.length === 0 && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>No hay horarios cargados.</td></tr>
            )}
            <FilaSinResultados filtros={filtros} total={horarios.length} cargando={cargando} columnas={3} nombreItems="horarios" />
            {paginacion.visibles.map((horario) => (
              <tr key={horario.id_horario}>
                <td><IconoCelda {...iconoHorario()} nombre={<span className="dato-numero">{Number(horario.cantidad_horas).toLocaleString('es-AR')} horas</span>} detalle="por jornada" /></td>
                <td><UsoCelda cantidad={horario.cantidad_empleados} singular="empleado" plural="empleados" /></td>
                <td className="col-acciones">
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/horarios/${horario.id_horario}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(horario)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar horario"
          mensaje={`¿Eliminar el horario de ${aEliminar.cantidad_horas} hs?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}