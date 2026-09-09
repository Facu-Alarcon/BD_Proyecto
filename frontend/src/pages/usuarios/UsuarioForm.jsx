import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';

export default function UsuarioForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [perfiles, setPerfiles] = useState([]);
  const [form, setForm] = useState({ usuario: '', id_perfil: '', contraseña: '' });
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);

  useEffect(() => {
    api.get('/perfiles/').then(({ data }) => setPerfiles(data));
  }, []);

  useEffect(() => {
    if (!editando) return;
    api.get(`/usuarios/${id}/`).then(({ data }) => {
      setForm({ usuario: data.usuario, id_perfil: data.id_perfil, contraseña: '' });
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
        await api.put(`/usuarios/${id}/`, form);
      } else {
        await api.post('/usuarios/', form);
      }
      navigate('/usuarios');
    } catch (err) {
      if (err.response?.status === 400) {
        setErrores(err.response.data);
      } else {
        setErrores({ detail: 'No se pudo guardar el usuario.' });
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
          <h1>{editando ? 'Editar Usuario' : 'Nuevo Usuario'}</h1>
        </div>
      </div>

      <div className="card" style={{ padding: 28, maxWidth: 480 }}>
        <form onSubmit={handleSubmit}>
          {errores.detail && <div className="alert alert-error">{errores.detail}</div>}

          <div className="form-field">
            <label htmlFor="id_perfil">Perfil</label>
            <select
              id="id_perfil"
              value={form.id_perfil}
              onChange={(e) => actualizar('id_perfil', e.target.value)}
              required
            >
              <option value="">Seleccionar...</option>
              {perfiles.map((p) => (
                <option key={p.id_perfil} value={p.id_perfil}>{p.tipo_perfil}</option>
              ))}
            </select>
            {errores.id_perfil && <span className="form-error">{errores.id_perfil}</span>}
          </div>

          <div className="form-field">
            <label htmlFor="usuario">Nombre de usuario</label>
            <input
              id="usuario"
              value={form.usuario}
              onChange={(e) => actualizar('usuario', e.target.value)}
              required
            />
            {errores.usuario && <span className="form-error">{errores.usuario}</span>}
          </div>

          <div className="form-field">
            <label htmlFor="contraseña">Contraseña</label>
            <input
              id="contraseña"
              type="password"
              value={form.contraseña}
              onChange={(e) => actualizar('contraseña', e.target.value)}
              required={!editando}
            />
            <span className="form-hint">
              {editando ? 'Dejar en blanco para mantener la contraseña actual.' : 'Obligatoria para un usuario nuevo.'}
            </span>
            {errores.contraseña && <span className="form-error">{errores.contraseña}</span>}
          </div>

          <button type="submit" className="btn btn-primary" disabled={guardando}>
            {guardando ? 'Guardando...' : 'Guardar'}
          </button>{' '}
          <button type="button" className="btn btn-secondary" onClick={() => navigate('/usuarios')}>
            Cancelar
          </button>
        </form>
      </div>
    </div>
  );
}
