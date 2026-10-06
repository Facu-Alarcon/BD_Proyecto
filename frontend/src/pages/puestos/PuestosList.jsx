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
import { iconoPuesto } from '../../utils/iconosModulos';

// Lista de Puestos de trabajo, con el sueldo de cada uno.
export default function PuestosList() {
  // Qué puede hacer el usuario en este módulo según su perfil (si no puede gestionar, solo ve la tabla)
  const { puedeGestionar } = usePermiso('puestos');
  const [puestos, setPuestos] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  // Trae todos los registros del backend y los guarda para la tabla
  function cargar() {
    setCargando(true);
    api
      .get('/puestos/')
      .then(({ data }) => setPuestos(data))
      .catch(() => setError('No se pudieron cargar los puestos.'))
      .finally(() => setCargando(false));
  }

  // Se cargan una sola vez, al abrir la pantalla
  useEffect(cargar, []);

  // Se ejecuta al confirmar en la ventana de "¿Eliminar?". Si el backend no deja borrarlo
  // (por ejemplo, porque está en uso en otra tabla) se muestra el motivo que devuelve.
  async function confirmarEliminar() {
    setEliminando(true);
    try {
      await api.delete(`/puestos/${aEliminar.id_puesto}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el puesto.');
    } finally {
      setEliminando(false);
    }
  }

  // Filtros de esta pantalla (ver hooks/useFiltros.js)
  const configFiltros = [
    { tipo: 'texto', id: 'texto', placeholder: 'Nombre del puesto', campos: (p) => [p.nombre_puesto] },
    { tipo: 'rango', id: 'sueldo', label: 'Sueldo', input: 'number', valor: (p) => p.sueldo_monto },
  ];
  const filtros = useFiltros(puestos, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Puestos</h1>
        </div>
        {puedeGestionar && <Link to="/puestos/nuevo" className="btn btn-primary">+ Nuevo Puesto</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={puestos.length} cargando={cargando} nombreItems="puestos" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
        {/* Tabla con las filas de la página actual (paginacion.visibles) */}
        <table className="data-table">
          <thead>
            <tr>
              <th>Puesto</th>
              <th>Sueldo</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && puestos.length === 0 && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>No hay puestos cargados.</td></tr>
            )}
            <FilaSinResultados filtros={filtros} total={puestos.length} cargando={cargando} columnas={3} nombreItems="puestos" />
            {paginacion.visibles.map((puesto) => (
              <tr key={puesto.id_puesto}>
                <td><IconoCelda {...iconoPuesto(puesto.nombre_puesto)} nombre={puesto.nombre_puesto} /></td>
                <td>${Number(puesto.sueldo_monto).toLocaleString('es-AR')}</td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/puestos/${puesto.id_puesto}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(puesto)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar puesto"
          mensaje={`¿Eliminar el puesto "${aEliminar.nombre_puesto}"?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}
