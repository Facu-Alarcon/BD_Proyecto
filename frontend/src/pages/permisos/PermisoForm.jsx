import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';

export default function PermisoForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [form, setForm] = useState({
    nombre_permiso: '',
    descripcion_permiso: '',
    estado_permiso: true,
  });
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);

  useEffect(() => {
    if (!editando) return;
    api.get(`/permisos/${id}/`).then(({ data }) => {
      setForm(data);
      setCargando(false);
    });
  }, [id, editando]);

  function actualizar(campo, valor) {
    setForm((f) => ({ ...f, [campo]: valor }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setGuardando(true);
    setErrores({});
    try {
      if (editando) {
        await api.put(`/permisos/${id}/`, form);
      } else {
        await api.post('/permisos/', form);
      }
      navigate('/permisos');
    } catch (err) {
      if (err.response?.status === 400) {
        setErrores(err.response.data);
      } else {
        setErrores({ detail: 'No se pudo guardar el permiso.' });
      }
    } finally {
      setGuardando(false);
    }
  }

  if (cargando) return <p>Cargando...</p>;

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>{editando ? 'Editar Permiso' : 'Nuevo Permiso'}</h1>
        </div>
      </div>

      <div className="card" style={{ padding: 28, maxWidth: 480 }}>
        <form onSubmit={handleSubmit}>
          {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

          <div className="form-field">
            <label htmlFor="nombre_permiso">Nombre del Permiso</label>
            <input
              id="nombre_permiso"
              value={form.nombre_permiso}
              onChange={(e) => actualizar('nombre_permiso', e.target.value)}
              required
            />
            {errores.nombre_permiso && <span className="form-error">{errores.nombre_permiso}</span>}
          </div>

          <div className="form-field">
            <label htmlFor="descripcion_permiso">Descripción</label>
            <input
              id="descripcion_permiso"
              value={form.descripcion_permiso}
              onChange={(e) => actualizar('descripcion_permiso', e.target.value)}
            />
          </div>

          <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
            <input
              type="checkbox"
              checked={form.estado_permiso}
              onChange={(e) => actualizar('estado_permiso', e.target.checked)}
            />
            Activo
          </label>

          <button type="submit" className="btn btn-primary" disabled={guardando}>
            {guardando ? 'Guardando...' : 'Guardar'}
          </button>{' '}
          <button type="button" className="btn btn-secondary" onClick={() => navigate('/permisos')}>
            Cancelar
          </button>
        </form>
      </div>
    </div>
  );
}
