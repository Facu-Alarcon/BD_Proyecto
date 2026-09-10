import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import api from '../../api/client';
import FormModal from '../../components/FormModal';
import SuccessModal from '../../components/SuccessModal';

export default function UsuarioForm() {
  const { id } = useParams();
  const editando = Boolean(id);
  const navigate = useNavigate();

  const [perfiles, setPerfiles] = useState([]);
  const [form, setForm] = useState({ usuario: '', id_perfil: '', contraseña: '' });
  const [errores, setErrores] = useState({});
  const [cargando, setCargando] = useState(editando);
  const [guardando, setGuardando] = useState(false);
  const [guardadoOk, setGuardadoOk] = useState(false);

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
        setGuardadoOk(true);
      } else {
        await api.post('/usuarios/', form);
        navigate('/usuarios');
      }
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

  if (guardadoOk) {
    return (
      <SuccessModal
        titulo="Usuario modificado correctamente"
        subtitulo={form.usuario}
        textoBoton="Volver a usuarios"
        onContinuar={() => navigate('/usuarios')}
      />
    );
  }

  const formulario = (
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
          placeholder="Ej: nombre.apellido"
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
        {guardando ? 'Guardando...' : editando ? 'Guardar cambios' : 'Crear usuario'}
      </button>{' '}
      <button type="button" className="btn btn-secondary" onClick={() => navigate('/usuarios')}>
        {editando ? 'Descartar cambios' : 'Cancelar'}
      </button>
    </form>
  );

  if (editando) {
    return (
      <FormModal titulo="Editar usuario" subtitulo={form.usuario} onClose={() => navigate('/usuarios')}>
        {formulario}
      </FormModal>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Nuevo Usuario</h1>
        </div>
      </div>
      <div className="card" style={{ padding: 28, maxWidth: 480 }}>
        {formulario}
      </div>
    </div>
  );
}
