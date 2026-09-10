import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';
import { IconEditar, IconEliminar } from '../../components/icons';
import ConfirmModal from '../../components/ConfirmModal';

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

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Empleados</h1>
        </div>
        {puedeGestionar && <Link to="/empleados/nuevo" className="btn btn-primary">+ Nuevo Empleado</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Nombre</th>
              <th>Teléfono</th>
              <th>Email</th>
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
            {empleados.map((empleado) => (
              <tr key={empleado.id_empleado}>
                <td>{empleado.nombre_emp} {empleado.apellido_emp}</td>
                <td>{empleado.telefono_emp}</td>
                <td>{empleado.email_emp}</td>
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
