import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';

export default function ClientesList() {
  const { puedeGestionar } = usePermiso('clientes');
  const [clientes, setClientes] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  function cargar() {
    setCargando(true);
    api
      .get('/clientes/')
      .then(({ data }) => setClientes(data))
      .catch(() => setError('No se pudieron cargar los clientes.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function eliminar(cliente) {
    if (!window.confirm(`¿Eliminar al cliente "${cliente.nombre_cliente} ${cliente.apellido_cliente}"?`)) return;
    try {
      await api.delete(`/clientes/${cliente.id_cliente}/`);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el cliente.');
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Clientes</h1>
        </div>
        {puedeGestionar && <Link to="/clientes/nuevo" className="btn btn-primary">+ Nuevo Cliente</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Nombre</th>
              <th>Domicilio</th>
              <th>Teléfono</th>
              <th>Email</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && clientes.length === 0 && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>No hay clientes cargados.</td></tr>
            )}
            {clientes.map((cliente) => (
              <tr key={cliente.id_cliente}>
                <td>{cliente.nombre_cliente} {cliente.apellido_cliente}</td>
                <td>{cliente.domicilio_cliente}</td>
                <td>{cliente.telefono_cliente}</td>
                <td>{cliente.email_cliente}</td>
                <td>
                  {puedeGestionar ? (
                    <>
                      <Link to={`/clientes/${cliente.id_cliente}/editar`} className="btn btn-secondary btn-sm">Editar</Link>{' '}
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => eliminar(cliente)}>Eliminar</button>
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
