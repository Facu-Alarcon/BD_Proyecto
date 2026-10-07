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
import { formatearTelefono } from '../../utils/formato';

// Lista de Clientes: tabla con buscador, paginación y botones para editar o eliminar.
export default function ClientesList() {
  // Qué puede hacer el usuario en este módulo según su perfil (si no puede gestionar, solo ve la tabla)
  const { puedeGestionar } = usePermiso('clientes');
  const [clientes, setClientes] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');
  const [aEliminar, setAEliminar] = useState(null);
  const [eliminando, setEliminando] = useState(false);

  // Trae todos los registros del backend y los guarda para la tabla
  function cargar() {
    setCargando(true);
    api
      .get('/clientes/')
      .then(({ data }) => setClientes(data))
      .catch(() => setError('No se pudieron cargar los clientes.'))
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
      await api.delete(`/clientes/${aEliminar.id_cliente}/`);
      setAEliminar(null);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el cliente.');
    } finally {
      setEliminando(false);
    }
  }

  // Filtros de esta pantalla (ver hooks/useFiltros.js)
  const configFiltros = [
    {
      tipo: 'texto', id: 'texto', placeholder: 'Nombre, apellido, teléfono, email o domicilio',
      // El teléfono va también con formato, así se encuentra escribiéndolo como se ve en la tabla
      campos: (c) => [`${c.nombre_cliente} ${c.apellido_cliente}`, c.telefono_cliente, formatearTelefono(c.telefono_cliente), c.email_cliente, c.domicilio_cliente],
    },
  ];
  const filtros = useFiltros(clientes, configFiltros);
  // De las filas filtradas se muestran de a 10 (ver hooks/usePaginacion.js)
  const paginacion = usePaginacion(filtros.filtradas, filtros.valores);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Clientes</h1>
        </div>
        {puedeGestionar && <Link to="/clientes/nuevo" className="btn btn-primary">+ Nuevo Cliente</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <BarraFiltros config={configFiltros} filtros={filtros} total={clientes.length} cargando={cargando} nombreItems="clientes" />

      <div className="card">
        {/* Paginación arriba de la tabla, para no tener que bajar hasta el final */}
        <Paginacion paginacion={paginacion} posicion="arriba" />
        {/* Tabla con las filas de la página actual (paginacion.visibles) */}
        <table className="data-table">
          <thead>
            <tr>
              <th>Cliente</th>
              <th>Contacto</th>
              <th>Domicilio</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={4} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && clientes.length === 0 && (
              <tr><td colSpan={4} style={{ textAlign: 'center' }}>No hay clientes cargados.</td></tr>
            )}
            <FilaSinResultados filtros={filtros} total={clientes.length} cargando={cargando} columnas={4} nombreItems="clientes" />
            {paginacion.visibles.map((cliente) => (
              <tr key={cliente.id_cliente}>
                <td>
                  <PersonaCelda nombre={cliente.nombre_cliente} apellido={cliente.apellido_cliente} />
                </td>
                {/* Mail y teléfono juntos en una sola columna */}
                <td><ContactoCelda email={cliente.email_cliente} telefono={cliente.telefono_cliente} /></td>
                <td>{cliente.domicilio_cliente}</td>
                <td>
                  {puedeGestionar ? (
                    <div className="actions-cell">
                      <Link to={`/clientes/${cliente.id_cliente}/editar`} className="btn btn-secondary btn-sm" title="Editar"><IconEditar /></Link>
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => setAEliminar(cliente)} title="Eliminar"><IconEliminar /></button>
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
          titulo="Eliminar cliente"
          mensaje={`¿Eliminar al cliente "${aEliminar.nombre_cliente} ${aEliminar.apellido_cliente}"?`}
          confirmando={eliminando}
          onCancelar={() => setAEliminar(null)}
          onConfirmar={confirmarEliminar}
        />
      )}
    </div>
  );
}