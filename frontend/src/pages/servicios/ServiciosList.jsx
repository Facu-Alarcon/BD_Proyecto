import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { usePermiso } from '../../hooks/usePermiso';

export default function ServiciosList() {
  const { puedeGestionar } = usePermiso('servicios');
  const [servicios, setServicios] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  function cargar() {
    setCargando(true);
    api
      .get('/servicios/')
      .then(({ data }) => setServicios(data))
      .catch(() => setError('No se pudieron cargar los servicios.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function eliminar(servicio) {
    if (!window.confirm(`¿Eliminar el servicio "${servicio.tipo_servicio}"?`)) return;
    try {
      await api.delete(`/servicios/${servicio.id_servicio}/`);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el servicio.');
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Servicios</h1>
        </div>
        {puedeGestionar && <Link to="/servicios/nuevo" className="btn btn-primary">+ Nuevo Servicio</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Servicio</th>
              <th>Precio</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && servicios.length === 0 && (
              <tr><td colSpan={3} style={{ textAlign: 'center' }}>No hay servicios cargados.</td></tr>
            )}
            {servicios.map((servicio) => (
              <tr key={servicio.id_servicio}>
                <td>{servicio.tipo_servicio}</td>
                <td>${Number(servicio.precio_servicio).toLocaleString('es-AR')}</td>
                <td>
                  {puedeGestionar ? (
                    <>
                      <Link to={`/servicios/${servicio.id_servicio}/editar`} className="btn btn-secondary btn-sm">Editar</Link>{' '}
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => eliminar(servicio)}>Eliminar</button>
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
