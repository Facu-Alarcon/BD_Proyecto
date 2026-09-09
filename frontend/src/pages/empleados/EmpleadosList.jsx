import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';

export default function EmpleadosList() {
  const { puedeGestionar } = usePermiso('empleados');
  const [empleados, setEmpleados] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  function cargar() {
    setCargando(true);
    api
      .get('/empleados/')
      .then(({ data }) => setEmpleados(data))
      .catch(() => setError('No se pudieron cargar los empleados.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function eliminar(empleado) {
    if (!window.confirm(`¿Eliminar al empleado "${empleado.nombre_emp} ${empleado.apellido_emp}"?`)) return;
    try {
      await api.delete(`/empleados/${empleado.id_empleado}/`);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el empleado.');
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
                    <>
                      <Link to={`/empleados/${empleado.id_empleado}/editar`} className="btn btn-secondary btn-sm">Editar</Link>{' '}
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => eliminar(empleado)}>Eliminar</button>
                    </>
                  ) : (
                    <span className="form-hint">Solo lectura</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
