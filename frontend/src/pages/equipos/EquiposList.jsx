import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../../api/client';
import { colorEstadoEquipo } from '../../utils/estadoEquipo';
import { usePermiso } from '../../hooks/usePermiso';

export default function EquiposList() {
  const { puedeGestionar } = usePermiso('equipos');
  const [equipos, setEquipos] = useState([]);
  const [cargando, setCargando] = useState(true);
  const [error, setError] = useState('');

  function cargar() {
    setCargando(true);
    api
      .get('/equipos/')
      .then(({ data }) => setEquipos(data))
      .catch(() => setError('No se pudieron cargar los equipos.'))
      .finally(() => setCargando(false));
  }

  useEffect(cargar, []);

  async function eliminar(equipo) {
    if (!window.confirm(`¿Eliminar el equipo "${equipo.nombre_equipo}"?`)) return;
    try {
      await api.delete(`/equipos/${equipo.id_equipo}/`);
      cargar();
    } catch (err) {
      alert(err.response?.data?.detail || 'No se pudo eliminar el equipo.');
    }
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Equipos</h1>
          <p>Inventario de sonido, iluminación y estructura.</p>
        </div>
        {puedeGestionar && <Link to="/equipos/nuevo" className="btn btn-primary">+ Nuevo Equipo</Link>}
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      <div className="card">
        <table className="data-table">
          <thead>
            <tr>
              <th>Nombre</th>
              <th>Tipo</th>
              <th>Estado</th>
              <th>Cantidad</th>
              <th>Acciones</th>
            </tr>
          </thead>
          <tbody>
            {cargando && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>Cargando...</td></tr>
            )}
            {!cargando && equipos.length === 0 && (
              <tr><td colSpan={5} style={{ textAlign: 'center' }}>No hay equipos cargados.</td></tr>
            )}
            {equipos.map((equipo) => (
              <tr key={equipo.id_equipo}>
                <td>{equipo.nombre_equipo}</td>
                <td>{equipo.tipo_nombre}</td>
                <td><span className={`badge ${colorEstadoEquipo(equipo.estado_nombre).badge}`}>{equipo.estado_nombre}</span></td>
                <td>{equipo.cantidad_equipo}</td>
                <td>
                  {puedeGestionar ? (
                    <>
                      <Link to={`/equipos/${equipo.id_equipo}/editar`} className="btn btn-secondary btn-sm">Editar</Link>{' '}
                      <button type="button" className="btn btn-danger btn-sm" onClick={() => eliminar(equipo)}>Eliminar</button>
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
